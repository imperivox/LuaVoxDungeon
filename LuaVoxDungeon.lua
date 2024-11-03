math.randomseed(os.time())

-- Constants
local WIDTH = 50
local HEIGHT = 20
local WALL = '#'
local FLOOR = '.'
local PLAYER = '@'
local ENEMY = 'E'
local ITEM = 'i'
local BOSS = 'B'
local INITIAL_WALL_CHANCE = 0.40

-- Game configuration
local CONFIG = {
    ENEMIES_PER_WAVE = 5,
    ITEMS_PER_WAVE = 3,
    PLAYER_INITIAL_STATS = {
        hp = 100,
        attack = 10,
        defense = 5
    }
}

-- Game state
local dungeon = {}
local player = {
    x = 0, y = 0,
    hp = CONFIG.PLAYER_INITIAL_STATS.hp,
    maxHp = CONFIG.PLAYER_INITIAL_STATS.hp,
    attack = CONFIG.PLAYER_INITIAL_STATS.attack,
    defense = CONFIG.PLAYER_INITIAL_STATS.defense,
    level = 1,
    exp = 0,
    inventory = {},
    enemiesDefeated = 0,
    wave = 1
}
local enemies = {}
local items = {}
local boss = nil

-- Calculate distance between two points
local function calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

-- Error handling wrapper
local function protected(f, ...)
    local status, result = pcall(f, ...)
    if not status then
        print("An error occurred: " .. tostring(result))
        io.read()
        return false
    end
    return result
end

-- Position validation
local function isValidPosition(x, y)
    return x >= 1 and x <= WIDTH and y >= 1 and y <= HEIGHT
end

-- Enemy position tracking helper function
local function isPositionOccupied(x, y, enemies, excludeEnemy)
    if not isValidPosition(x, y) then return true end
    
    -- Check for boss
    if boss and boss.x == x and boss.y == y then
        return true
    end
    
    for _, enemy in ipairs(enemies) do
        if enemy ~= excludeEnemy and enemy.x == x and enemy.y == y then
            return true
        end
    end
    return false
end

-- Get available adjacent positions
local function getAvailablePositions(x, y, dungeon, enemies, excludeEnemy)
    local positions = {}
    local directions = {{0,1}, {0,-1}, {1,0}, {-1,0}, {1,1}, {1,-1}, {-1,1}, {-1,-1}}
    
    for _, dir in ipairs(directions) do
        local newX = x + dir[1]
        local newY = y + dir[2]
        if isValidPosition(newX, newY) and dungeon[newY] and dungeon[newY][newX] == FLOOR 
           and not isPositionOccupied(newX, newY, enemies, excludeEnemy) then
            table.insert(positions, {x = newX, y = newY})
        end
    end
    return positions
end

-- Enhanced item definitions
local itemTypes = {
    {
        name = "Health Potion",
        symbol = 'HP',
        effect = function(p)
            p.hp = math.min(p.maxHp, p.hp + 30)
            return "Healed 30 HP!"
        end,
    },
    {
        name = "Steel Sword",
        symbol = 'SS',
        effect = function(p)
            p.attack = p.attack + 5
            return "Attack increased by 5!"
        end,
    },
    {
        name = "Chain Mail",
        symbol = 'CM',
        effect = function(p)
            p.defense = p.defense + 3
            return "Defense increased by 3!"
        end,
    },
    {
        name = "Strength Elixir",
        symbol = 'SE',
        effect = function(p)
            p.attack = p.attack + 8
            p.defense = p.defense - 2
            return "Attack +8, Defense -2!"
        end,
    },
    {
        name = "Guardian Elixir",
        symbol = 'GE',
        effect = function(p)
            p.defense = p.defense + 6
            p.attack = p.attack - 3
            return "Defense +6, Attack -3!"
        end,
    }
}

-- Boss definitions
local bossTypes = {
    {
        name = "Dungeon Overlord",
        hp = 200,
        attack = 20,
        defense = 15,
        special = function(p)
            local damage = 25
            p.hp = math.max(1, p.hp - damage) -- Prevent instant death
            return string.format("Overlord uses Dark Strike for %d damage!", damage)
        end,
        movementPattern = function(boss, player)
            -- Teleport when health is low
            if boss.hp < boss.maxHp * 0.3 and math.random() < 0.3 then
                return math.random(2, WIDTH-1), math.random(2, HEIGHT-1)
            end
            -- Normal movement
            return nil, nil
        end
    },
    {
        name = "Ancient Guardian",
        hp = 150,
        attack = 25,
        defense = 20,
        special = function(p)
            local defenseReduction = math.min(3, p.defense - 1) -- Prevent negative defense
            p.defense = math.max(1, p.defense - defenseReduction)
            return string.format("Guardian weakens your armor by %d!", defenseReduction)
        end,
        movementPattern = function(boss, player)
            -- Charge at player when health is low
            if boss.hp < boss.maxHp * 0.5 then
                local dx = player.x - boss.x
                local dy = player.y - boss.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist > 0 then
                    return boss.x + math.floor(dx/dist), boss.y + math.floor(dy/dist)
                end
            end
            return nil, nil
        end
    }
}

-- Reset game state
local function resetGame()
    dungeon = {}
    enemies = {}
    items = {}
    boss = nil
    player = {
        x = 0, 
        y = 0,
        hp = CONFIG.PLAYER_INITIAL_STATS.hp,
        maxHp = CONFIG.PLAYER_INITIAL_STATS.hp,
        attack = CONFIG.PLAYER_INITIAL_STATS.attack,
        defense = CONFIG.PLAYER_INITIAL_STATS.defense,
        level = 1,
        exp = 0,
        inventory = {},
        enemiesDefeated = 0,
        wave = 1
    }
end

-- Random walls generation
local function initializeDungeon()
    for y = 1, HEIGHT do
        dungeon[y] = {}
        for x = 1, WIDTH do
            dungeon[y][x] = math.random() < INITIAL_WALL_CHANCE and WALL or FLOOR
        end
    end
end

-- Apply cellular automata rules to generate cave-like structures
local function applyAutomata()
    local newDungeon = {}
    for y = 1, HEIGHT do
        newDungeon[y] = {}
        for x = 1, WIDTH do
            local wallCount = 0
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local nx, ny = x + dx, y + dy
                    if nx < 1 or nx > WIDTH or ny < 1 or ny > HEIGHT then
                        wallCount = wallCount + 1
                    elseif dungeon[ny][nx] == WALL then
                        wallCount = wallCount + 1
                    end
                end
            end
            newDungeon[y][x] = wallCount >= 5 and WALL or FLOOR
        end
    end
    dungeon = newDungeon
end

-- Generate the dungeon using cellular automata
local function generateDungeon()
    initializeDungeon()
    for i = 1, 4 do
        applyAutomata()
    end
end

-- Spawn player in a valid position (on floor)
local function spawnPlayer()
    repeat
        player.x = math.random(2, WIDTH - 1)
        player.y = math.random(2, HEIGHT - 1)
    until dungeon[player.y][player.x] == FLOOR
end

-- Calculate enemy stats based on wave number
local function getEnemyStats(wave)
    -- Ensure wave is a number and greater than 0
    wave = math.max(1, tonumber(wave) or 1)
    return {
        hp = math.random(30, 35) + (wave - 1) * 5,
        attack = math.random(5, 7) + math.floor((wave - 1) * 1.5),
        defense = math.random(2, 4) + math.floor((wave - 1) * 0.5),
        level = math.random(wave, wave + 4)
    }
end

-- Spawn enemies in a valid position (on floor)
local function spawnEnemies(count, wave)
    -- Input validation
    count = math.max(0, tonumber(count) or 0)
    wave = math.max(1, tonumber(wave) or 1)
    
    local spawnedCount = 0
    local maxAttempts = 100
    local totalAttempts = 0
    
    -- Ensure enemies table exists
    enemies = enemies or {}
    
    while spawnedCount < count and totalAttempts < maxAttempts do
        totalAttempts = totalAttempts + 1
        local stats = getEnemyStats(wave)
        
        -- Create enemy with validated positions
        local enemy = {
            x = 0,
            y = 0,
            hp = stats.hp,
            attack = stats.attack,
            defense = stats.defense,
            level = stats.level
        }
        
        -- Find valid spawn position
        local x = math.random(2, WIDTH - 1)
        local y = math.random(2, HEIGHT - 1)
        
        -- Validate dungeon position and player distance
        if dungeon[y] and dungeon[y][x] == FLOOR and
           type(player.x) == "number" and type(player.y) == "number" and
           math.abs(x - player.x) > 5 and
           math.abs(y - player.y) > 5 then
            
            -- Check distance from other enemies with nil protection
            local tooClose = false
            for _, existingEnemy in ipairs(enemies) do
                if existingEnemy and 
                   type(existingEnemy.x) == "number" and 
                   type(existingEnemy.y) == "number" and
                   calculateDistance(x, y, existingEnemy.x, existingEnemy.y) < 3 then
                    tooClose = true
                    break
                end
            end
            
            if not tooClose then
                enemy.x = x
                enemy.y = y
                table.insert(enemies, enemy)
                spawnedCount = spawnedCount + 1
            end
        end
    end
    
    -- Fallback spawning with relaxed restrictions if needed
    if spawnedCount == 0 then
        local fallbackCount = math.ceil(count/2)
        while spawnedCount < fallbackCount and totalAttempts < maxAttempts * 2 do
            totalAttempts = totalAttempts + 1
            local x = math.random(2, WIDTH - 1)
            local y = math.random(2, HEIGHT - 1)
            
            if dungeon[y] and dungeon[y][x] == FLOOR then
                local stats = getEnemyStats(wave)
                local enemy = {
                    x = x,
                    y = y,
                    hp = stats.hp,
                    attack = stats.attack,
                    defense = stats.defense,
                    level = stats.level
                }
                table.insert(enemies, enemy)
                spawnedCount = spawnedCount + 1
            end
        end
    end
    
    -- Return success status and number of enemies spawned
    return spawnedCount > 0, spawnedCount
end

-- Spawn items on random positions
local function spawnItems(count)
    for i = 1, count do
        local itemType = itemTypes[math.random(#itemTypes)]
        local item = {
            x = 0,
            y = 0,
            type = itemType
        }
        repeat
            item.x = math.random(2, WIDTH - 1)
            item.y = math.random(2, HEIGHT - 1)
        until dungeon[item.y][item.x] == FLOOR
        table.insert(items, item)
    end
end

-- Combat system
local function combat(attacker, defender, isCritical)
    local damage = math.max(1, attacker.attack - defender.defense)
    defender.hp = defender.hp - damage
    return damage
end

-- Boss Battle mechanics
local function processBoss()
    if not boss or boss.hp <= 0 then return true end
    
    -- Process boss special abilities and movement
    if math.abs(boss.x - player.x) + math.abs(boss.y - player.y) <= 2 then
        -- Attack phase
        local damage = math.max(1, boss.attack - player.defense)
        player.hp = player.hp - damage
        print(string.format("%s attacks for %d damage!", boss.name, damage))
        
        -- Special attack
        if boss.specialCooldown <= 0 then
            print(boss.special(player))
            boss.specialCooldown = 3
        else
            boss.specialCooldown = boss.specialCooldown - 1
        end
    else
        -- Movement phase
        local newX, newY = boss.movementPattern(boss, player)
        if newX and newY and isValidPosition(newX, newY) and dungeon[newY][newX] == FLOOR then
            boss.x = newX
            boss.y = newY
            print(string.format("%s repositions!", boss.name))
        else
            -- Default movement towards player
            local availablePositions = getAvailablePositions(boss.x, boss.y, dungeon, enemies)
            if #availablePositions > 0 then
                local bestPos = availablePositions[1]
                local bestDist = math.huge
                for _, pos in ipairs(availablePositions) do
                    local dist = calculateDistance(pos.x, pos.y, player.x, player.y)
                    if dist < bestDist then
                        bestDist = dist
                        bestPos = pos
                    end
                end
                boss.x = bestPos.x
                boss.y = bestPos.y
            end
        end
    end
    
    return player.hp > 0
end
-- Boss battle
local function spawnBoss()
    local bossType = bossTypes[math.random(#bossTypes)]
    boss = {
        x = 0,
        y = 0,
        name = bossType.name,
        hp = bossType.hp + (player.wave * 20),
        maxHp = bossType.hp + (player.wave * 20), -- Added maxHp for percentage calculations
        attack = bossType.attack + (player.wave * 2),
        defense = bossType.defense + math.floor(player.wave * 1.5),
        special = bossType.special,
        specialCooldown = 3,
        movementPattern = bossType.movementPattern
    }
    
    -- Find a valid spawn position away from player
    local attempts = 0
    local maxAttempts = 100
    repeat
        boss.x = math.random(2, WIDTH - 1)
        boss.y = math.random(2, HEIGHT - 1)
        attempts = attempts + 1
    until (dungeon[boss.y][boss.x] == FLOOR and
           calculateDistance(boss.x, boss.y, player.x, player.y) > 10) or
           attempts >= maxAttempts
    
    if attempts >= maxAttempts then
        -- Fallback spawn position if no ideal position found
        repeat
            boss.x = math.random(2, WIDTH - 1)
            boss.y = math.random(2, HEIGHT - 1)
        until dungeon[boss.y][boss.x] == FLOOR
    end
end

-- Process enemy turns and check for new wave
local function processEnemies()
    -- Process boss first if present
    if boss then
        if boss.hp <= 0 then
            print(string.format("\n%s has been defeated!", boss.name))
            boss = nil
            player.wave = player.wave + 1
            player.exp = player.exp + 100
            io.read()
        else
            if not processBoss() then
                return false
            end
        end
    elseif #enemies == 0 then
        if player.wave % 5 == 0 and not boss then
            print("\nA powerful presence appears...")
            spawnBoss()
            io.read()
            return true
        end
       
        player.wave = player.wave + 1
        print(string.format("\nWave %d completed! Starting wave %d...", player.wave - 1, player.wave))
        protected(spawnEnemies, CONFIG.ENEMIES_PER_WAVE, player.wave)
        protected(spawnItems, CONFIG.ITEMS_PER_WAVE)
       
        io.read()
        return true
    end

    -- Process enemy movement and combat
    local i = #enemies
    while i >= 1 do
        local enemy = enemies[i]
       
        -- Check if enemy is defeated
        if enemy.hp <= 0 then
            table.remove(enemies, i)
            player.enemiesDefeated = player.enemiesDefeated + 1
            player.exp = player.exp + enemy.level * 5
           
            -- Level up check
            if player.exp >= player.level * 20 then
                player.level = player.level + 1
                player.maxHp = player.maxHp + 10
                player.hp = player.maxHp
                player.attack = player.attack + 3
                player.defense = player.defense + 2
                print(string.format("\nLevel Up! You are now level %d!", player.level))
                io.read()
            end
           
            print(string.format("\nEnemy defeated! Gained %d XP!", enemy.level * 5))
            io.read()
        else
            -- Enemy movement and attack logic
            if calculateDistance(enemy.x, enemy.y, player.x, player.y) <= 1 then
                -- Enemy is adjacent to player - attack
                local damage = combat(enemy, player)
                print(string.format("\nEnemy (Level %d) attacks you for %d damage!", enemy.level, damage))
                io.read()
               
                if player.hp <= 0 then
                    return false
                end
            else
                -- Enemy movement
                local availablePositions = getAvailablePositions(enemy.x, enemy.y, dungeon, enemies, enemy)
                if #availablePositions > 0 then
                    -- Move towards player
                    local bestPos = availablePositions[1]
                    local bestDist = math.huge
                   
                    for _, pos in ipairs(availablePositions) do
                        local dist = calculateDistance(pos.x, pos.y, player.x, player.y)
                        if dist < bestDist then
                            bestDist = dist
                            bestPos = pos
                        end
                    end
                   
                    enemy.x = bestPos.x
                    enemy.y = bestPos.y
                end
            end
        end
        
        i = i - 1
    end
   
    return true
end

-- Modified drawGame to include boss
local function drawGame()
    protected(os.execute, "cls")
    
    -- Store original values
    local playerTile = dungeon[player.y][player.x]
    local enemyTiles = {}
    local itemTiles = {}
    
    -- Store enemy positions
    for _, enemy in ipairs(enemies) do
        if isValidPosition(enemy.x, enemy.y) then
            enemyTiles[#enemyTiles + 1] = {
                x = enemy.x,
                y = enemy.y,
                tile = dungeon[enemy.y][enemy.x]
            }
            dungeon[enemy.y][enemy.x] = ENEMY
        end
    end
    
    -- Store boss position
    local bossTile = nil
    if boss then
        bossTile = {
            x = boss.x,
            y = boss.y,
            tile = dungeon[boss.y][boss.x]
        }
        dungeon[boss.y][boss.x] = BOSS
    end
    
    -- Store item positions
    for _, item in ipairs(items) do
        if isValidPosition(item.x, item.y) then
            itemTiles[#itemTiles + 1] = {
                x = item.x,
                y = item.y,
                tile = dungeon[item.y][item.x]
            }
            dungeon[item.y][item.x] = ITEM
        end
    end
    
    -- Draw player
    dungeon[player.y][player.x] = PLAYER
    
    -- Print dungeon
    for y = 1, HEIGHT do
        local row = ""
        for x = 1, WIDTH do
            row = row .. (dungeon[y][x] or WALL)
        end
        print(row)
    end
    
    -- Restore original tiles
    dungeon[player.y][player.x] = playerTile
    
    for _, saved in ipairs(enemyTiles) do
        dungeon[saved.y][saved.x] = saved.tile
    end
    
    if bossTile then
        dungeon[bossTile.y][bossTile.x] = bossTile.tile
    end
    
    for _, saved in ipairs(itemTiles) do
        dungeon[saved.y][saved.x] = saved.tile
    end
    
    -- Print status
    print(string.format("\nWave: %d | Enemies Defeated: %d", player.wave, player.enemiesDefeated))
    print(string.format("HP: %d/%d | Level: %d | XP: %d/%d",
        player.hp, player.maxHp, player.level, player.exp, player.level * 20))
    print(string.format("Attack: %d | Defense: %d", player.attack, player.defense))
    
    -- Print boss status if present
    if boss then
        print(string.format("\nBoss: %s", boss.name))
        print(string.format("Boss HP: %d/%d", boss.hp, boss.maxHp))
    end
    
    print("\nInventory:")
    for i, item in ipairs(player.inventory) do
        print(i .. ". " .. item.name)
    end
end

-- Welcome screen
local function welcomeScreen()
    print([[
===============================================================================
 _                    _    _            ____                                    
| |    _   _  __ _  | |  | |  _____  _|  _ \  _   _ _ __   __ _  ___  ___  _ __  
| |   | | | |/ _` | | |  | | / _ \ \/ / | | || | | | '_ \ / _` |/ _ \/ _ \| '_ \ 
| |___| |_| | (_| | | |__| || (_) >  <| |_| || |_| | | | | (_| |  __/ (_) | | | |
|_____|\__,_|\__,_|  \____/  \___/_/\_\____/  \__,_|_| |_|\__, |\___|\___/|_| |_|
                                                          |___/                     
===============================================================================

                        >> Press ENTER to Start <<
    ]])
    io.read()
    os.execute("cls")
end

-- Game over screen
local function gameOver()
    os.execute("cls")
    print([[
===============================================================================
    ____                         ___                 
    / ___| __ _ _ __ ___   ___   / _ \__   _____ _ __ 
   | |  _ / _` | '_ ` _ \ / _ \ | | | \ \ / / _ \ '__|
   | |_| | (_| | | | | | |  __/ | |_| |\ V /  __/ |   
    \____|\__,_|_| |_| |_|\___|  \___/  \_/ \___|_|   
===============================================================================
    ]])
    print("\nFinal Stats:")
    print(string.format("Waves Completed: %d", player.wave - 1))
    print(string.format("Enemies Defeated: %d", player.enemiesDefeated))
    print(string.format("Level Reached: %d", player.level))
    print(string.format("XP Gained: %d", player.exp))
    print(string.format("Items Collected: %d", #player.inventory))
    print("\nPress 'R' to retry or 'Q' to quit")
    
    while true do
        local input = io.read():lower()
        if input == "r" then
            return true
        elseif input == "q" then
            return false
        end
    end
end

-- game loop
local function gameLoop()
    generateDungeon()
    spawnPlayer()
    spawnEnemies(CONFIG.ENEMIES_PER_WAVE, player.wave)
    spawnItems(CONFIG.ITEMS_PER_WAVE)

    while true do
        drawGame()
        print("\nWASD to move, E to use item, Q to quit")
        local input = io.read():lower()

        local dx, dy = 0, 0
        if input == "w" then dy = -1
        elseif input == "s" then dy = 1
        elseif input == "a" then dx = -1
        elseif input == "d" then dx = 1
        elseif input == "q" then break
        elseif input == "e" and #player.inventory > 0 then
            print("Select item (1-" .. #player.inventory .. "):")
            local itemIndex = tonumber(io.read())
            if itemIndex and itemIndex <= #player.inventory then
                local item = table.remove(player.inventory, itemIndex)
                print(item.effect(player))
                io.read()
            end
        end

        -- Process movement and combat
        local newX, newY = player.x + dx, player.y + dy
        if dungeon[newY][newX] == FLOOR then
            -- Check for enemies at the new position
            local enemyAtPos = nil
            for _, enemy in ipairs(enemies) do
                if enemy.x == newX and enemy.y == newY then
                    enemyAtPos = enemy
                    break
                end
            end

            -- Handle combat or movement
            if enemyAtPos then
                local damage = combat(player, enemyAtPos)
                print(string.format("You attack enemy (Level %d) for %d damage!", enemyAtPos.level, damage))
                io.read()
            else
                player.x = newX
                player.y = newY

                -- Check for items
                for i = #items, 1, -1 do
                    local item = items[i]
                    if item.x == player.x and item.y == player.y then
                        table.insert(player.inventory, item.type)
                        table.remove(items, i)
                        print("Picked up " .. item.type.name)
                        io.read()
                        break
                    end
                end
            end
        end

        -- Process enemies and check if player died
        if not processEnemies() then
            if gameOver() then
                resetGame()
                return true
            else
                return false
            end
        end
    end
    return false
end

local function mainLoop()
    while true do
        resetGame()
        if not gameLoop() then
            break
        end
    end
end

welcomeScreen()
mainLoop()
