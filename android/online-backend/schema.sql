-- Ultimate Tic/Tac/Toe asynchronous matches on a dedicated Neon Postgres project.
-- Android calls only the Neon Function; no SQL credentials leave the server.
-- The Function hashes per-install 256-bit guest credentials into user identities.
-- No Neon Data API access and no client-side SQL permissions.

create table if not exists public.ultttt_matches (
    id uuid primary key default gen_random_uuid(),
    invite_code text not null unique
        default upper(substring(replace(gen_random_uuid()::text, '-', '') from 1 for 12)),
    player_x text not null check (player_x ~ '^[0-9a-f]{64}$'),
    player_o text check (player_o ~ '^[0-9a-f]{64}$'),
    is_public boolean not null default false,
    moves jsonb not null default '[]'::jsonb check (jsonb_typeof(moves) = 'array'),
    status text not null default 'waiting'
        check (status in ('waiting', 'active', 'finished')),
    winner text check (winner in ('X', 'O', 'DRAW')),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint ultttt_different_players check (player_o is null or player_o <> player_x),
    constraint ultttt_status_players check (
        (status = 'waiting' and player_o is null and winner is null) or
        (status = 'active' and player_o is not null and winner is null) or
        (status = 'finished' and player_o is not null and winner is not null)
    )
);

create index if not exists ultttt_matches_x_recent
    on public.ultttt_matches (player_x, updated_at desc);
create index if not exists ultttt_matches_o_recent
    on public.ultttt_matches (player_o, updated_at desc);

-- No client role has access to private match rows; server's owner role uses Neon DATABASE_URL.
alter table public.ultttt_matches enable row level security;
revoke all on public.ultttt_matches from public;

-- Server-side rules use a 1-indexed flat array of 81 cells:
-- 0 = empty, 1 = X, 2 = O. Board and cell inputs are 0-indexed.
create or replace function public.ultttt_board_status(p_cells integer[], p_board integer)
returns integer language plpgsql immutable strict security invoker set search_path = ''
as $$
declare
    v_a integer;
    v_b integer;
    v_c integer;
    v_start integer;
    v_line record;
    v_full boolean := true;
    v_i integer;
begin
    if p_board < 0 or p_board > 8 or array_length(p_cells, 1) <> 81 then
        raise exception 'Invalid board state';
    end if;
    v_start := p_board * 9;
    for v_line in
        select * from (values (1,2,3), (4,5,6), (7,8,9),
                              (1,4,7), (2,5,8), (3,6,9),
                              (1,5,9), (3,5,7)) as lines(a,b,c)
    loop
        v_a := p_cells[v_start + v_line.a];
        v_b := p_cells[v_start + v_line.b];
        v_c := p_cells[v_start + v_line.c];
        if v_a in (1,2) and v_a = v_b and v_b = v_c then
            return v_a;
        end if;
    end loop;
    for v_i in 1..9 loop
        if p_cells[v_start + v_i] = 0 then v_full := false; end if;
    end loop;
    if v_full then return 3; end if;
    return 0;
end;
$$;

create or replace function public.ultttt_game_status(p_cells integer[])
returns integer language plpgsql immutable strict security invoker set search_path = ''
as $$
declare
    v_boards integer[] := array_fill(0, array[9]);
    v_i integer;
    v_line record;
    v_owner integer;
    v_full boolean := true;
begin
    for v_i in 0..8 loop
        v_boards[v_i + 1] := public.ultttt_board_status(p_cells, v_i);
    end loop;
    for v_line in
        select * from (values (1,2,3), (4,5,6), (7,8,9),
                              (1,4,7), (2,5,8), (3,6,9),
                              (1,5,9), (3,5,7)) as lines(a,b,c)
    loop
        v_owner := v_boards[v_line.a];
        if v_owner in (1,2)
            and v_owner = v_boards[v_line.b]
            and v_owner = v_boards[v_line.c] then
            return v_owner;
        end if;
    end loop;
    for v_i in 1..9 loop
        if v_boards[v_i] = 0 then v_full := false; end if;
    end loop;
    if v_full then return 3; end if;
    return 0;
end;
$$;

create or replace function public.ultttt_create_match(p_actor text)
returns public.ultttt_matches language plpgsql security invoker set search_path = ''
as $$
declare
    v_user text := p_actor;
    v_match public.ultttt_matches;
begin
    if v_user is null or v_user !~ '^[0-9a-f]{64}$' then raise exception 'Invalid guest session'; end if;
    if (select count(*) from public.ultttt_matches
        where player_x = v_user and status = 'waiting'
          and created_at > now() - interval '14 days') >= 10 then
        raise exception 'You already have ten invitations awaiting an opponent';
    end if;
    insert into public.ultttt_matches(player_x) values (v_user)
        returning * into v_match;
    return v_match;
end;
$$;

-- Join the oldest open public queue match; create one if nobody is waiting.
-- Held row locks and SKIP LOCKED prevent two players claiming the same seat.
create or replace function public.ultttt_find_match(p_actor text)
returns public.ultttt_matches language plpgsql security invoker set search_path = ''
as $
declare
    v_user text := p_actor;
    v_match public.ultttt_matches;
begin
    if v_user is null or v_user !~ '^[0-9a-f]{64}$' then raise exception 'Invalid guest session'; end if;
    select * into v_match from public.ultttt_matches
        where status = 'waiting' and is_public
          and player_x <> v_user
          and created_at > now() - interval '14 days'
        order by created_at
        limit 1 for update skip locked;
    if found then
        update public.ultttt_matches set
            player_o = v_user, status = 'active', updated_at = now()
            where id = v_match.id returning * into v_match;
        return v_match;
    end if;
    -- Avoid creating a new waiting room on every tap / app restart.
    select * into v_match from public.ultttt_matches
        where player_x = v_user and status = 'waiting' and is_public
          and created_at > now() - interval '14 days'
        order by created_at desc limit 1;
    if found then return v_match; end if;
    if (select count(*) from public.ultttt_matches
        where player_x = v_user and status = 'waiting'
          and created_at > now() - interval '14 days') >= 10 then
        raise exception 'You already have ten invitations awaiting an opponent';
    end if;
    insert into public.ultttt_matches(player_x, is_public) values(v_user, true)
        returning * into v_match;
    return v_match;
end;
$;

create or replace function public.ultttt_join_match(p_actor text, p_invite_code text)
returns public.ultttt_matches language plpgsql security invoker set search_path = ''
as $$
declare
    v_user text := p_actor;
    v_match public.ultttt_matches;
begin
    if v_user is null or v_user !~ '^[0-9a-f]{64}$' then raise exception 'Invalid guest session'; end if;
    if p_invite_code is null or length(trim(p_invite_code)) <> 12
        or trim(p_invite_code) !~ '^[0-9A-Fa-f]{12}$' then
        raise exception 'Invalid invitation code';
    end if;
    update public.ultttt_matches
        set player_o = v_user, status = 'active', updated_at = now()
        where invite_code = upper(trim(p_invite_code))
          and status = 'waiting' and player_o is null and player_x <> v_user
          and created_at > now() - interval '14 days'
        returning * into v_match;
    if not found then raise exception 'Invitation expired, unavailable, or already joined'; end if;
    return v_match;
end;
$$;

create or replace function public.ultttt_play_move(
    p_actor text, p_match_id uuid, p_board integer, p_cell integer, p_expected_moves integer
)
returns public.ultttt_matches language plpgsql security invoker set search_path = ''
as $$
declare
    v_user text := p_actor;
    v_match public.ultttt_matches;
    v_cells integer[] := array_fill(0, array[81]);
    v_move jsonb;
    v_board integer;
    v_cell integer;
    v_index integer;
    v_count integer;
    v_forced integer := -1;
    v_mark integer;
    v_result integer;
begin
    if v_user is null or v_user !~ '^[0-9a-f]{64}$' then raise exception 'Invalid guest session'; end if;
    if p_expected_moves is null or p_expected_moves not between 0 and 81 then
        raise exception 'Expected move count is required';
    end if;
    if p_board is null or p_board not between 0 and 8
        or p_cell is null or p_cell not between 0 and 8 then
        raise exception 'Move out of bounds';
    end if;
    select * into v_match from public.ultttt_matches
        where id = p_match_id for update;
    if not found or (v_match.player_x is distinct from v_user
            and v_match.player_o is distinct from v_user) then
        raise exception 'Match not found';
    end if;
    if v_match.status <> 'active' or v_match.player_o is null then
        raise exception 'The match is not ready for moves';
    end if;
    v_count := jsonb_array_length(v_match.moves);
    if v_count <> p_expected_moves then
        raise exception 'Match changed; refresh before moving';
    end if;
    if v_count > 80 then raise exception 'Match is full'; end if;

    -- Reconstruct and validate the persisted history, never accept a client board.
    for v_index in 0..v_count - 1 loop
        v_move := v_match.moves -> v_index;
        if jsonb_typeof(v_move) <> 'object' or
           jsonb_typeof(v_move -> 'board') <> 'number' or
           jsonb_typeof(v_move -> 'cell') <> 'number' then
            raise exception 'Invalid saved match history';
        end if;
        v_board := (v_move ->> 'board')::integer;
        v_cell := (v_move ->> 'cell')::integer;
        if v_board not between 0 and 8 or v_cell not between 0 and 8 or
           (v_forced <> -1 and v_board <> v_forced) or
           v_cells[v_board * 9 + v_cell + 1] <> 0 or
           public.ultttt_board_status(v_cells, v_board) <> 0 or
           public.ultttt_game_status(v_cells) <> 0 then
            raise exception 'Illegal saved match history';
        end if;
        v_cells[v_board * 9 + v_cell + 1] := case when mod(v_index, 2) = 0 then 1 else 2 end;
        v_forced := case when public.ultttt_board_status(v_cells, v_cell) = 0
            then v_cell else -1 end;
    end loop;

    v_mark := case when mod(v_count, 2) = 0 then 1 else 2 end;
    if (v_mark = 1 and v_match.player_x <> v_user) or
       (v_mark = 2 and v_match.player_o <> v_user) then
        raise exception 'It is not your turn';
    end if;
    if (v_forced <> -1 and v_forced <> p_board) or
       v_cells[p_board * 9 + p_cell + 1] <> 0 or
       public.ultttt_board_status(v_cells, p_board) <> 0 or
       public.ultttt_game_status(v_cells) <> 0 then
        raise exception 'Illegal move';
    end if;

    v_cells[p_board * 9 + p_cell + 1] := v_mark;
    v_result := public.ultttt_game_status(v_cells);
    update public.ultttt_matches set
        moves = moves || jsonb_build_array(jsonb_build_object('board', p_board, 'cell', p_cell)),
        status = case when v_result = 0 then 'active' else 'finished' end,
        winner = case v_result when 1 then 'X' when 2 then 'O'
            when 3 then 'DRAW' else null end,
        updated_at = now()
    where id = v_match.id returning * into v_match;
    return v_match;
end;
$$;

-- Restrict entrypoints to the database owner used by Neon Functions.
revoke all on function public.ultttt_board_status(integer[],integer) from public;
revoke all on function public.ultttt_game_status(integer[]) from public;
revoke all on function public.ultttt_create_match(text) from public;
revoke all on function public.ultttt_find_match(text) from public;
revoke all on function public.ultttt_join_match(text,text) from public;
revoke all on function public.ultttt_play_move(text,uuid,integer,integer,integer) from public;
