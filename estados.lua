-- estados.lua

-- Vista: Menú de Inicio
function init_intro()
    music(-1)
    -- Tabla para gestionar dinámicamente las opciones del menú
    opciones = {
        {nombre="vidas pato", val=3, min=1, max=5},
        {nombre="rival", val=1, textos={"humano", "cpu"}},
        {nombre="rol humano", val=1, textos={"cazador", "pato"}}, -- NUEVA OPCIÓN
        {nombre="modo", val=1, textos={"infinito", "acotado", "desafio"}},
        {nombre="mapa", val=1, textos={"bosque", "lago", "selva"}}
    }
    sel_opc = 1 -- Índice de la opción seleccionada actualmente
end

function upd_intro()
    -- 1. Guardar el rival actual para saber si debemos saltar la opción
    local es_vs_cpu = (opciones[2].val == 2) -- True si seleccionó "cpu"

    -- 2. Navegación vertical (Arriba / Abajo)
    if btnp(2) then 
        sel_opc -= 1 
        sfx(45)
        -- Si retrocedemos y caemos en "rol humano" pero el rival es humano, nos la saltamos
        if (sel_opc == 3 and not es_vs_cpu) sel_opc -= 1
    end 
    if btnp(3) then 
        sel_opc += 1 
        sfx(45)
        -- Si avanzamos y caemos en "rol humano" pero el rival es humano, nos la saltamos
        if (sel_opc == 3 and not es_vs_cpu) sel_opc += 1
    end 
    
    -- Limitar el cursor dentro de la tabla
    sel_opc = mid(1, sel_opc, #opciones)
    
    -- 3. Modificar valor de la opción actual (Izquierda / Derecha)
    local op = opciones[sel_opc]
    if btnp(0) then 
        op.val -= 1 
        sfx(46)
    end 
    if btnp(1) then 
        op.val += 1 
        sfx(46)
    end 
    
    -- Limitar los valores según el tipo de opción
    if op.min then
        op.val = mid(op.min, op.val, op.max)
    else
        op.val = mid(1, op.val, #op.textos)
    end
    
    -- Iniciar juego (Botón Z o X)
    if btnp(4) or btnp(5) then 
        sfx(47)
        chg_vista("ingame") 
    end
end

function drw_intro()
    cls(0)
    
    -- Fondo animado: Estrellas en el espacio
    for i=1, 80 do
        local speed = (i % 3) + 1
        local x = (i * 73 - t() * speed * 15) % 128
        local y = (i * 91) % 128
        local col = 5 -- Azul oscuro para las lejanas
        if speed == 2 then col = 6 end -- Gris para las medias
        if speed == 3 then col = 7 end -- Blanco para las cercanas
        
        pset(x, y, col)
    end
    
    -- Título
    print("pato a la fuga", 38, 10, 11)
    print("configuracion de partida", 14, 25, 7)
    
    local es_vs_cpu = (opciones[2].val == 2)
    
    -- Dibujar opciones dinámicamente
    local y = 40
    for i=1, #opciones do
        local op = opciones[i]
        local color = 6 -- Color gris por defecto
        
        -- Lógica visual para la opción condicional "rol humano"
        if i == 3 and not es_vs_cpu then
            -- Si no es vs CPU, mostramos la opción desactivada en gris oscuro (color 5)
            print(op.nombre .. ": n/a", 24, y, 5)
        else
            -- Comportamiento normal para las demás opciones
            if (i == sel_opc) color = 10 -- Amarillo si está seleccionado
            
            local txt_val = op.val
            if op.textos then txt_val = op.textos[op.val] end
            
            print(op.nombre .. ": " .. txt_val, 24, y, color)
            
            -- Dibujar el cursor indicador
            if (i == sel_opc) print(">", 16, y, 10)
        end
        
        y += 12
    end
    
    print("presiona z para jugar", 22, 112, 5)
end

-- Vista: Juego principal
function init_game()
    music(0) -- Iniciar la música
    -- Inyectar configuración del menú PRIMERO
    vidas_iniciales = opciones[1].val
    tipo_rival = opciones[2].val -- 1: humano, 2: cpu
    rol_humano = opciones[3].val -- 1: cazador, 2: pato
    modo_juego = opciones[4].val -- 1: infinito, 2: acotado, 3: desafio
    escenario = opciones[5].val

    ents = {} 
    cazador = make_cazador()
    pato = make_pato()
    pato.vida = vidas_iniciales
    
    -- Activar "interruptores" de CPU
    cazador.is_cpu = (tipo_rival == 2 and rol_humano == 2)
    pato.is_cpu = (tipo_rival == 2 and rol_humano == 1)
    
    init_nubes()

    -- Configurar Modos
    segundos = 0
    frames = 0
    tiempo_limite = 0
    
    if modo_juego == 2 then tiempo_limite = 60 end -- Acotado: 60s
    if modo_juego == 3 then tiempo_limite = 30 end -- Desafío: 30s
    
    -- Variables para el estado final
    mensaje_final = ""
    victoria = false
end

function upd_game()
    frames += 1
    if (frames % 30 == 0) segundos += 1
    
    upd_nubes()

    for e in all(ents) do e.upd() end
    
    -- REGLAS DE LOS MODOS DE JUEGO
    if modo_juego == 1 then
        -- 1. MODO INFINITO: Jugar hasta que el pato muera
        if pato.vida <= 0 then
            mensaje_final = "el cazador atrapo al pato en " .. segundos .. "s"
            -- Si es vs CPU, gana el humano si era el cazador
            victoria = (tipo_rival == 1) or (rol_humano == 1) 
            chg_vista("fin")
        end
        
    elseif modo_juego == 2 then
        -- 2. MODO ACOTADO: Límite de 60 segundos
        if pato.vida <= 0 then
            mensaje_final = "cazador gana! le sobraron " .. (tiempo_limite - segundos) .. "s"
            victoria = (tipo_rival == 1) or (rol_humano == 1)
            chg_vista("fin")
        elseif segundos >= tiempo_limite then
            mensaje_final = "pato sobrevive! el tiempo se agoto."
            victoria = (tipo_rival == 1) or (rol_humano == 2)
            chg_vista("fin")
        end
        
    elseif modo_juego == 3 then
        -- 3. MODO DESAFIO: Retos específicos por rol
        if rol_humano == 1 then
            -- Reto Cazador: Eliminar al pato en menos de 30s
            if pato.vida <= 0 then
                mensaje_final = "reto superado! pato cazado a tiempo."
                victoria = true
                chg_vista("fin")
            elseif segundos >= tiempo_limite then
                mensaje_final = "reto fallido! el pato escapo."
                victoria = false
                chg_vista("fin")
            end
        else
            -- Reto Pato: Sobrevivir 30s SIN RECIBIR DAÑO (Intocable)
            if pato.vida < vidas_iniciales then
                mensaje_final = "reto fallido! recibiste dano."
                victoria = false
                chg_vista("fin")
            elseif segundos >= tiempo_limite then
                mensaje_final = "reto superado! fuiste intocable."
                victoria = true
                chg_vista("fin")
            end
        end
    end
end

function drw_game()
    cls()
    -- Coordenadas X para cada mapa (Bosque=0, Lago=48, Selva=32)
    local coords_x = {0, 48, 32}
    local mapa_x = coords_x[escenario]
    map(mapa_x, 0, 0, 0, 16, 16) 
    
    drw_nubes()

    for e in all(ents) do e.drw() end
    
    -- Lógica del HUD según el modo (Cronómetro vs Cuenta regresiva)
    if modo_juego == 1 then
        print("tiempo: " .. segundos, 4, 4, 7)
    else
        local restante = tiempo_limite - segundos
        local color_tiempo = (restante <= 10) and 8 or 7 -- Rojo si quedan 10s
        print("restante: " .. restante, 4, 4, color_tiempo)
    end
    
    print("vidas pato: " .. pato.vida, 70, 4, 7)
end

-- Vista: Fin de Juego
function init_fin()
    music(-1)
    ents = {} -- Vaciamos entidades para que no sigan sonando/moviéndose
    
    -- Inicializar partículas para la pantalla final
    fin_parts = {}
    if victoria then
        -- Confeti de colores brillantes (colores 8 al 14 de PICO-8)
        for i=1, 30 do
            add(fin_parts, {
                x = rnd(128),
                y = rnd(120) - 130, -- Inician arriba de la pantalla
                vel = 0.6 + rnd(1.2),
                dx = rnd(0.8) - 0.4,
                color = 8 + flr(rnd(7))
            })
        end
    else
        -- Gotas de lluvia (grises oscuro 5 y claro 6)
        for i=1, 40 do
            add(fin_parts, {
                x = rnd(128),
                y = rnd(128),
                vel = 2.5 + rnd(2),
                color = (rnd(1) > 0.5) and 5 or 6
            })
        end
    end
end

function upd_fin()
    -- Volver al menú
    if btnp(4) or btnp(5) then 
        chg_vista("intro") 
        return
    end
    
    frames += 1
    
    -- Actualizar movimiento de partículas
    for p in all(fin_parts) do
        if victoria then
            p.y += p.vel
            p.x += sin(frames / 12 + p.vel) * 0.3 -- Balanceo suave
            if p.y > 128 then
                p.y = -5
                p.x = rnd(128)
            end
        else
            p.y += p.vel
            if p.y > 128 then
                p.y = -5
                p.x = rnd(128)
            end
        end
    end
end

function sub_find(str, target)
    local len_str = #str
    local len_target = #target
    for i=1, len_str - len_target + 1 do
        if sub(str, i, i + len_target - 1) == target then
            return i
        end
    end
    return nil
end

function draw_wrapped_msg(msg, y, color)
    local line1, line2 = msg, ""
    
    -- Intentar dividir por "! "
    local split_idx = sub_find(msg, "! ")
    if split_idx then
        line1 = sub(msg, 1, split_idx)
        line2 = sub(msg, split_idx + 2)
    else
        -- Intentar dividir por " en "
        split_idx = sub_find(msg, " en ")
        if split_idx then
            line1 = sub(msg, 1, split_idx - 1)
            line2 = sub(msg, split_idx + 1)
        end
    end
    
    -- Imprimir ambas líneas centradas
    local off1 = (128 - (#line1 * 4)) / 2
    print(line1, off1, y, color)
    
    if #line2 > 0 then
        local off2 = (128 - (#line2 * 4)) / 2
        print(line2, off2, y + 8, color)
    end
end

function drw_fin()
    cls(0)
    
    -- Determinar el texto del ganador según las variables
    local winner_text = ""
    if victoria then
        if (rol_humano == 1) winner_text = "ganador: cazador"
        if (rol_humano == 2) winner_text = "ganador: pato"
    else
        if (rol_humano == 1) winner_text = "ganador: pato"
        if (rol_humano == 2) winner_text = "ganador: cazador"
    end
    
    if victoria then
        -- Fondo verde oscuro con confeti
        rectfill(0, 0, 127, 127, 3)
        for p in all(fin_parts) do
            rectfill(p.x, p.y, p.x + 1, p.y + 1, p.color)
        end
        
        -- Cartel de Victoria
        rectfill(12, 10, 115, 30, 0)
        rect(11, 9, 116, 31, 10) -- Borde dorado
        
        -- Título parpadeante dinámico
        local color_tit = (frames % 12 < 6) and 10 or 7
        local off_tit = (128 - (#winner_text * 4)) / 2
        print(winner_text, off_tit, 16, color_tit)
        
        -- Dibujar personaje victorioso 
        local jump_y = 52 + sin(frames /6) * 5
        if rol_humano == 2 then
            -- Pato 
            spr(1, 56, jump_y, 1, 1, false, false)
        else
            -- Cazador
            spr(2, 56, jump_y, 1, 1)
        end
        
        -- Cuadro de Puntaje/Info más alto
        rectfill(10, 85, 117, 122, 0)
        rect(9, 84, 118, 123, 11) 
        
       
        draw_wrapped_msg(mensaje_final, 89, 7)
        print("presiona z para volver", 18, 109, 10)
        
    else
        -- Fondo gris oscuro con lluvia 
        rectfill(0, 0, 127, 127, 5)
        for p in all(fin_parts) do
            line(p.x, p.y, p.x, p.y + 2, p.color)
        end
        
        -- Cartel de Derrota
        rectfill(12, 10, 115, 30, 0)
        rect(11, 9, 116, 31, 8) 
        
        -- Título dinámico
        local off_tit = (128 - (#winner_text * 4)) / 2
        print(winner_text, off_tit, 16, 8)
        
        -- Escena derrota
        if rol_humano == 2 then
            -- Pato derrotado 
            sspr(16, 8, 8, 8, 48, 50, 32, 32)
            
            -- Pato boca abajo 
            spr(1, 24, 70, 1, 1, false, true)
        else
            -- Cazador triste en el suelo y pato volando arriba burlándose
            spr(2, 24, 70, 1, 1) -- Cazador cabizbajo
            
            -- Pato volando por el cielo
            local pato_x = 50 + cos(frames / 20) * 35
            local pato_y = 40 + sin(frames / 8) * 3
            spr(1, pato_x, pato_y, 1, 1, (cos(frames/20) < 0), (frames % 8 >= 4))
        end
        
        -- Cuadro de Info más alto
        rectfill(10, 85, 117, 122, 0)
        rect(9, 84, 118, 123, 8) -- Borde rojo
        
        -- Imprimir el mensaje final envuelto y prompt
        draw_wrapped_msg(mensaje_final, 89, 7)
        print("presiona z para volver", 18, 109, 8)
    end
end

-- Diccionario maestro de Vistas
vistas = {
    intro = { ini=init_intro, upd=upd_intro, drw=drw_intro },
    ingame = { ini=init_game, upd=upd_game, drw=drw_game },
    fin = { ini=init_fin, upd=upd_fin, drw=drw_fin } 
}

-- Función para transicionar limpiamente entre estados
function chg_vista(v)
    vista = v
    vistas[v].ini()
    _update = vistas[v].upd
    _draw = vistas[v].drw
end