-- estados.lua

-- Vista: Menú de Inicio
function init_intro()
    -- Tabla para gestionar dinámicamente las opciones del menú
    opciones = {
        {nombre="vidas pato", val=3, min=1, max=5},
        {nombre="rival", val=1, textos={"humano", "cpu"}},
        {nombre="rol humano", val=1, textos={"cazador", "pato"}},
        {nombre="modo", val=1, textos={"infinito", "acotado", "desafio"}},
        {nombre="mapa", val=1, textos={"bosque", "lago", "noche"}}
    }
    sel_opc = 1 -- Índice de la opción seleccionada actualmente
end

function upd_intro()
    -- Guardar el rival actual para saber si debemos saltar la opción
    local es_vs_cpu = (opciones[2].val == 2) -- True si seleccionó "cpu"

    -- Navegación vertical (Arriba / Abajo)
    if btnp(2) then 
        sel_opc -= 1 
        -- Si retrocedemos y caemos en "rol humano" pero el rival es humano, nos la saltamos
        if (sel_opc == 3 and not es_vs_cpu) sel_opc -= 1
    end 
    if btnp(3) then 
        sel_opc += 1 
        -- Si avanzamos y caemos en "rol humano" pero el rival es humano, nos la saltamos
        if (sel_opc == 3 and not es_vs_cpu) sel_opc += 1
    end 
    
    -- Limitar el cursor dentro de la tabla
    sel_opc = mid(1, sel_opc, #opciones)
    
    -- Modificar valor de la opción actual (Izquierda / Derecha)
    local op = opciones[sel_opc]
    if btnp(0) then op.val -= 1 end 
    if btnp(1) then op.val += 1 end 
    
    -- Limitar los valores según el tipo de opción
    if op.min then
        op.val = mid(op.min, op.val, op.max)
    else
        op.val = mid(1, op.val, #op.textos)
    end
    
    -- Iniciar juego (Botón Z o X)
    if btnp(4) or btnp(5) then 
        chg_vista("ingame") 
    end
end

function drw_intro()
    cls()
    -- Título
    print("pato a la fuga", 22, 10, 11)
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
    ents = {} 
    cazador = make_cazador()
    pato = make_pato()
    
    -- Inyectar configuración del menú
    vidas_iniciales = opciones[1].val
    pato.vida = vidas_iniciales
    tipo_rival = opciones[2].val -- 1: humano, 2: cpu
    rol_humano = opciones[3].val -- 1: cazador, 2: pato
    modo_juego = opciones[4].val -- 1: infinito, 2: acotado, 3: desafio
    escenario = opciones[5].val
    
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
        -- MODO INFINITO: Jugar hasta que el pato muera
        if pato.vida <= 0 then
            mensaje_final = "el cazador atrapo al pato en " .. segundos .. "s"
            -- Si es vs CPU, gana el humano si era el cazador
            victoria = (tipo_rival == 1) or (rol_humano == 1) 
            chg_vista("fin")
        end
        
    elseif modo_juego == 2 then
        -- MODO ACOTADO: Límite de 60 segundos
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
        -- MODO DESAFIO: Retos específicos por rol
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
    map(0,0,0,0,16,16) 
    
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
    -- Vaciamos entidades para que no sigan moviéndose
    ents = {}
end

function upd_fin()
    -- Volver al menú
    if btnp(4) or btnp(5) then chg_vista("intro") end
end

function drw_fin()
    cls()
    if victoria then
        rectfill(0,0,127,127, 3) -- Fondo verde oscuro para victoria
        print("¡ VICTORIA !", 44, 40, 11)
    else
        rectfill(0,0,127,127, 2) -- Fondo rojo oscuro para derrota
        print("¡ DERROTA !", 44, 40, 8)
    end
    
    -- Mensaje descriptivo centrado (aprox)
    print(mensaje_final, 10, 60, 7)
    
    print("presiona z para volver al menu", 8, 100, 6)
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