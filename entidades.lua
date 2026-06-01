-- entidades.lua
ents = {}

function make_entidad(px, py, sprite_id)
    local e = {
        x = px,
        y = py,
        sp = sprite_id,
        vida = 1,
        dx = 0,
        dy = 0
    }
    
    e.upd = function()
        e.x += e.dx
        e.y += e.dy
    end
    
    e.drw = function()
        if (e.sp != 0) spr(e.sp, e.x, e.y)
    end
    
    add(ents, e)
    return e
end

function make_cazador()
    local c = make_entidad(60, 110, 2)
    c.vel = 2
    c.angulo = 0.25 -- Ángulo inicial: 0.25 apunta directamente hacia arriba
    
    local oupd = c.upd
    c.upd = function()
        c.dx = 0
        
        -- Bloque de control: Humano vs CPU
        if not c.is_cpu then
            -- Movimiento horizontal
            if (btn(0)) c.dx = -c.vel
            if (btn(1)) c.dx = c.vel
            
            -- Apuntado (Arriba/Abajo)
            if (btn(2)) c.angulo -= 0.008 -- Gira hacia la derecha
            if (btn(3)) c.angulo += 0.008 -- Gira hacia la izquierda
            
            -- Limitar el arco de disparo para que apunte hacia el cielo
            c.angulo = mid(0.05, c.angulo, 0.45)
            
            -- Disparar bala
            if btnp(4) then
                local centro_x = c.x + 4 
                local centro_y = c.y
                local vel_bala = 4
                
                make_bala(
                    centro_x, 
                    centro_y, 
                    cos(c.angulo) * vel_bala, 
                    sin(c.angulo) * vel_bala
                )
            end
        else
            -- LÓGICA DE CPU DEL CAZADOR
            -- Perseguir al pato horizontalmente (con una pequeña zona muerta)
            if pato.x > c.x + 8 then 
                c.dx = c.vel * 0.7 -- Es un poco más lento que el humano
            elseif pato.x < c.x - 8 then 
                c.dx = -c.vel * 0.7 
            end
            
            -- Apuntado Automático (Trigonometría)
            local dist_x = (pato.x + 4) - (c.x + 4)
            local dist_y = (pato.y + 4) - c.y
            local ang_ideal = atan2(dist_x, dist_y)
            
            -- Transición suave para que la mira no salte instantáneamente
            c.angulo += (ang_ideal - c.angulo) * 0.1
            c.angulo = mid(0.05, c.angulo, 0.45)
            
            -- Disparar con ritmo dinámico (Dificultad progresiva)
            if not c.cpu_timer then c.cpu_timer = 45 end
            c.cpu_timer -= 1
            
            if c.cpu_timer <= 0 then
                local vel_bala = 4
                make_bala(
                    c.x + 4, c.y, 
                    cos(c.angulo) * vel_bala, sin(c.angulo) * vel_bala
                )
                
                -- DIFICULTAD:
                -- Reducimos el tiempo de espera según los segundos que hayan pasado.
                -- Usamos min() para que la reducción no pase de 25 frames (así no dispara infinitamente rápido).
                local reduccion = min(segundos, 25) 
                
                local espera_base = 30 - reduccion -- Pasa de 30 frames a 5 frames
                local espera_azar = 40 - reduccion -- Pasa de 40 frames a 15 frames
                
                c.cpu_timer = espera_base + rnd(espera_azar)
            end
        end
        c.x = mid(0, c.x, 120)
        oupd()
    end
    
    local odrw = c.drw
    c.drw = function()
        odrw() -- Dibuja el sprite del cazador primero
        
        -- Lógica visual de la mira
        local radio = 20 -- Distancia de la mira al cazador
        local mirilla_x = c.x + 4 + cos(c.angulo) * radio
        local mirilla_y = c.y + 4 + sin(c.angulo) * radio
        
        -- Dibujar una retícula técnica
        line(mirilla_x - 2, mirilla_y, mirilla_x + 2, mirilla_y, 8)
        line(mirilla_x, mirilla_y - 2, mirilla_x, mirilla_y + 2, 8)
        pset(mirilla_x, mirilla_y, 12)
    end
    
    return c
end

-- Constructor de balas
function make_bala(px, py, dir_x, dir_y)
    local b = make_entidad(px, py, 0)
    b.dx = dir_x
    b.dy = dir_y
    b.vida = 100
    
    local oupd = b.upd
    b.upd = function()
        b.vida -= 1
        
        -- DETECCIÓN FULMINANTE DE BORDES LATERALES
        -- Si la posición X calculada para el siguiente frame se sale de los límites reales,
        -- borramos la bala INMEDIATAMENTE y cortamos la ejecución de la función con 'return'.
        local siguiente_x = b.x + b.dx
        if siguiente_x <= 1 or siguiente_x >= 126 or b.y < -2 or b.y > 130 or b.vida <= 0 then
            del(ents, b)
            return
        end
        
        -- Colisión Segura contra el Pato
        if pato != nil then
            if abs(b.x - (pato.x + 4)) < 5 and abs(b.y - (pato.y + 4)) < 5 then
                pato.vida -= 1
                del(ents, b)
                return
            end
        end
        
        oupd()
    end
    
    b.drw = function()
        circfill(b.x, b.y, 1, 0) -- Proyectil negro
    end
    
    return b
end

function make_pato()
    local p = make_entidad(60, 20, 1)
    p.vel = 1.5
    p.vida = 3
    
    -- variables de la mecánica 
    p.dash_timer = 0    -- duración del impulso
    p.dash_cd = 0       -- enfriamiento (cooldown)
    p.direccion = 1     -- 1 derecha, -1 izquierda
    
    local oupd = p.upd
    p.upd = function()
        p.dx = 0
        
        -- reducir contadores
        if (p.dash_timer > 0) p.dash_timer -= 1
        if (p.dash_cd > 0) p.dash_cd -= 1
        
        -- Bloque de control: Humano vs CPU
        if not p.is_cpu then
            -- determinar dirección para el dash
            if (btn(0,1)) p.direccion = -1
            if (btn(1,1)) p.direccion = 1
            
            -- activar dash (botón x del j2)
            if btnp(5,1) and p.dash_cd <= 0 then
                p.dash_timer = 8  -- dura 8 frames
                p.dash_cd = 60    -- 2 segundos de espera (a 30fps)
                sfx(5)            
            end
            
            -- lógica de movimiento e instanciación de la estela 
            if p.dash_timer > 0 then
                p.dx = p.direccion * 4 
                
                -- CREA UNA PLUMA CADA 2 FRAMES MIENTRAS DURA EL DASH
                if frames % 2 == 0 then 
                    make_pluma(p.x + 2, p.y + 2)
                end
            else
                -- Movimiento horizontal normal si no hay dash
                if (btn(0,1)) p.dx = -p.vel
                if (btn(1,1)) p.dx = p.vel
            end
        else
            -- LÓGICA DE CPU DEL PATO
            if not p.cpu_timer then p.cpu_timer = 0 end
            p.cpu_timer -= 1
            
            -- Cambios de dirección erráticos
            if p.cpu_timer <= 0 then
                p.direccion = (rnd(1) > 0.5) and 1 or -1
                p.cpu_timer = 20 + rnd(30) -- Mantiene el rumbo entre 0.6s y 1.6s
            end
            
            -- Mantenerse dentro de la pantalla
            if p.x < 10 then p.direccion = 1 end
            if p.x > 110 then p.direccion = -1 end
            
            -- Instinto de Supervivencia (Usar Dash)
            -- Si el cazador está cerca en el eje X y tiene el dash cargado
            if abs(cazador.x - p.x) < 15 and p.dash_cd <= 0 then
                if rnd(1) > 0.85 then -- 15% de probabilidad por frame de entrar en pánico
                    p.dash_timer = 8
                    p.dash_cd = 60
                    sfx(5)
                end
            end
            
            -- Aplicar el movimiento resultante
            if p.dash_timer > 0 then
                p.dx = p.direccion * 4 
                if frames % 2 == 0 then make_pluma(p.x + 2, p.y + 2) end
            else
                p.dx = p.direccion * (p.vel * 0.8) -- Vuelo normal un poco más lento
            end
        end
        p.x = mid(0, p.x, 120)
        oupd()
    end
    
    local odrw = p.drw
    p.drw = function()
        -- Lógica de animación de alas 
        local sp_actual = 1
        if (frames % 8 >= 4) sp_actual = 17 
        
        -- Efecto visual de parpadeo durante el dash
        if p.dash_timer > 0 then
            pal(1, 7) -- el color oscuro parpadea a blanco
        end
        
        -- Dibujar el sprite (volteo corregido)
        -- Si p.direccion es < 0 (izq), volteamos el sprite que mira a la derecha
        local voltear_sprite = (p.direccion < 0)
        spr(sp_actual, p.x, p.y, 1, 1, voltear_sprite)
        
        pal() -- resetear colores
        
        -- Indicador de Cooldown (HUD sobre el pato)
        if p.dash_cd > 0 then
            rectfill(p.x, p.y-3, p.x+7, p.y-2, 5) -- fondo
            rectfill(p.x, p.y-3, p.x+(p.dash_cd/60)*7, p.y-2, 12) -- carga
        end
    end
    
    return p
end

function make_pluma(px, py)
    local pl = make_entidad(px, py, 33)
    pl.dx = rnd(1)-0.5 -- pequeña deriva lateral
    pl.dy = 0.5        -- cae lentamente
    pl.vida = 15       -- dura medio segundo (15 frames)
    
    local oupd = pl.upd
    pl.upd = function()
        pl.vida -= 1
        if (pl.vida <= 0) del(ents, pl)
        oupd()
    end
    
    pl.drw = function()
        -- hace que la pluma se vuelva gris antes de desaparecer
        if (pl.vida < 5) pal(7, 6) 
        spr(pl.sp, pl.x, pl.y)
        pal()
    end
end

-- SISTEMA DE NUBES
nubes = {}

function init_nubes()
    nubes = {}
    -- Generar 5 nubes iniciales esparcidas
    for i=1, 8 do
        add(nubes, {
            x = rnd(128),
            y = rnd(60) + 10,     -- Altura aleatoria en la mitad superior
            vel = 0.1 + rnd(0.3), -- Velocidades diferentes
            sp = 3 })              
    end
end

function upd_nubes()
    for n in all(nubes) do
        n.x -= n.vel -- Las nubes se mueven suavemente hacia la izquierda
        
        -- Si una nube sale por el borde izquierdo, reaparece por la derecha
        if n.x < -16 then
            n.x = 130
            n.y = rnd(60) + 10
            n.vel = 0.1 + rnd(0.3)
        end
    end
end

function drw_nubes()
    -- Le decimos que el color 12 (celeste) ahora es transparente
    palt(12, true) 
     
    -- Dibujamos todas las nubes
    for n in all(nubes) do
        spr(n.sp, n.x, n.y)
    end
    
    -- Reseteamos la transparencia a la normalidad 
    -- para que no afecte a los demás sprites del juego
    palt()
end