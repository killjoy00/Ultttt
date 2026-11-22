-- Smoke-test the dedicated Neon Postgres backend. Run after schema.sql.
-- This block leaves no permanent games: it deliberately runs in a transaction.
begin;

do $$
declare
    v_a text := repeat('a', 64);
    v_b text := repeat('b', 64);
    v_c text := repeat('c', 64);
    v_private public.ultttt_matches;
    v_joined public.ultttt_matches;
    v_moved public.ultttt_matches;
    v_queue public.ultttt_matches;
    v_paired public.ultttt_matches;
    v_blocked boolean;
    v_cells integer[] := array_fill(0, array[81]);
begin
    if public.ultttt_board_status(v_cells, 0) <> 0 or
       public.ultttt_game_status(v_cells) <> 0 then
        raise exception 'Empty board evaluation failed';
    end if;
    v_cells[1] := 1; v_cells[2] := 1; v_cells[3] := 1;
    if public.ultttt_board_status(v_cells, 0) <> 1 then
        raise exception 'X mini-board win evaluation failed';
    end if;
    v_cells[10] := 1; v_cells[11] := 1; v_cells[12] := 1;
    v_cells[19] := 1; v_cells[20] := 1; v_cells[21] := 1;
    if public.ultttt_game_status(v_cells) <> 1 then
        raise exception 'Overall game win evaluation failed';
    end if;
    v_cells := array_fill(0, array[81]);
    v_cells[37] := 2; v_cells[40] := 2; v_cells[43] := 2;
    if public.ultttt_board_status(v_cells, 4) <> 2 then
        raise exception 'O mini-board win evaluation failed';
    end if;

    select * into v_private from public.ultttt_create_match(v_a);
    if v_private.status <> 'waiting' or v_private.player_x <> v_a then
        raise exception 'Invite creation failed';
    end if;

    v_blocked := false;
    begin
        perform public.ultttt_join_match(v_a, v_private.invite_code);
    exception when raise_exception then
        v_blocked := true;
    end;
    if not v_blocked then raise exception 'Guest joined their own invitation'; end if;

    select * into v_joined from public.ultttt_join_match(v_b, v_private.invite_code);
    if v_joined.status <> 'active' or v_joined.player_o <> v_b then
        raise exception 'Invite join failed';
    end if;

    v_blocked := false;
    begin
        perform public.ultttt_play_move(v_b, v_private.id, 4, 2, 0);
    exception when raise_exception then
        v_blocked := true;
    end;
    if not v_blocked then raise exception 'Non-active player made the first move'; end if;

    select * into v_moved from public.ultttt_play_move(v_a, v_private.id, 4, 2, 0);
    if jsonb_array_length(v_moved.moves) <> 1 then
        raise exception 'First move was not saved';
    end if;

    v_blocked := false;
    begin
        perform public.ultttt_play_move(v_b, v_private.id, 1, 0, 1);
    exception when raise_exception then
        v_blocked := true;
    end;
    if not v_blocked then raise exception 'Forced-board rule bypassed'; end if;

    select * into v_moved from public.ultttt_play_move(v_b, v_private.id, 2, 0, 1);
    if jsonb_array_length(v_moved.moves) <> 2 then
        raise exception 'Legal second move failed';
    end if;

    v_blocked := false;
    begin
        perform public.ultttt_play_move(v_c, v_private.id, 0, 0, 2);
    exception when raise_exception then
        v_blocked := true;
    end;
    if not v_blocked then raise exception 'Non-participant moved'; end if;

    v_blocked := false;
    begin
        perform public.ultttt_play_move(v_a, v_private.id, 0, 0, 0);
    exception when raise_exception then
        v_blocked := true;
    end;
    if not v_blocked then raise exception 'Stale expected move version was accepted'; end if;

    select * into v_queue from public.ultttt_find_match(v_a);
    if v_queue.status <> 'waiting' or not v_queue.is_public then
        raise exception 'Public matchmaking queue failed';
    end if;
    select * into v_paired from public.ultttt_find_match(v_c);
    if v_paired.id <> v_queue.id or v_paired.player_o <> v_c then
        raise exception 'Public matchmaking did not pair guests';
    end if;
end;
$$;

rollback;
