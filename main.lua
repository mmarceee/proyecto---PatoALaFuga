-- main.lua

function _init()
    cartdata("pato_sj_2026_final")
    highscore = dget(0)
    
    if (not registro) registro = {}
    
    -- Inyectar el estado inicial (Pantalla de inicio)
    chg_vista("intro")
end