-- Smoke tests for board/win evaluation. Run after applying schema.sql.
-- These do not create accounts or games and leave no data behind.
do $$
declare
    v_cells integer[] := array_fill(0, array[81]);
begin
    if public.ultttt_board_status(v_cells, 0) <> 0
        or public.ultttt_game_status(v_cells) <> 0 then
        raise exception 'Empty board must be in progress';
    end if;

    -- X wins mini-board 0, but not the full game.
    v_cells[1] := 1;
    v_cells[2] := 1;
    v_cells[3] := 1;
    if public.ultttt_board_status(v_cells, 0) <> 1
        or public.ultttt_game_status(v_cells) <> 0 then
        raise exception 'Mini-board X win detection failed';
    end if;

    -- X wins the top row of mini-boards, completing the game.
    v_cells[10] := 1;
    v_cells[11] := 1;
    v_cells[12] := 1;
    v_cells[19] := 1;
    v_cells[20] := 1;
    v_cells[21] := 1;
    if public.ultttt_game_status(v_cells) <> 1 then
        raise exception 'Overall X win detection failed';
    end if;

    -- An independent board must recognize an O win.
    v_cells := array_fill(0, array[81]);
    v_cells[37] := 2;
    v_cells[40] := 2;
    v_cells[43] := 2;
    if public.ultttt_board_status(v_cells, 4) <> 2 then
        raise exception 'Mini-board O column win detection failed';
    end if;
end;
$$;
