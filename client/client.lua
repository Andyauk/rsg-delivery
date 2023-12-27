local RSGCore = exports['rsg-core']:GetCoreObject()
local carthash = nil
local cargohash = nil
local lighthash = nil
local distance = nil
local wagonSpawned = false
local MissionSecondsRemaining = 0
local missiontime = 0
local missionactive = false

-- mission timer
local function MissionTimer(missiontime, vehicle, endcoords)
    MissionSecondsRemaining = (missiontime * 60)

    Citizen.CreateThread(function()
        while true do
            if MissionSecondsRemaining > 0 then
                Wait(1000)
                MissionSecondsRemaining = MissionSecondsRemaining - 1
                if MissionSecondsRemaining == 0 and wagonSpawned == true then
                    ClearGpsMultiRoute(endcoords)
                    endcoords = nil
                    DeleteVehicle(vehicle)
                    wagonSpawned = false
                    missionactive = false
                    lib.notify({ title = Lang:t('label.failed_del'), description = Lang:t('label.failed_del_descr'), type = 'error' })
                end
            end

            if missionactive == true then
                local minutes = math.floor((MissionSecondsRemaining % 3600) / 60) -- El resto de segundos convertidos a minutos
                local seconds = MissionSecondsRemaining % 60 -- Los segundos restantes
                
                lib.showTextUI(Lang:t('label.delivery_time')..minutes..':'..seconds)
                Wait(0)
            else
                lib.hideTextUI()
            end
            Wait(0)
        end
    end)
end

function DrawText3D(x, y, z, text)
    local onScreen,_x,_y=GetScreenCoordFromWorldCoord(x, y, z)
    SetTextScale(0.35, 0.35)
    SetTextFontForCurrentCommand(9)
    SetTextColor(255, 255, 255, 215)
    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    SetTextCentre(1)
    DisplayText(str,_x,_y)
end

-- prompts and blips
Citizen.CreateThread(function()
    for delivery, v in pairs(Config.DeliveryLocations) do
        exports['rsg-core']:createPrompt(v.deliveryid, v.startcoords, RSGCore.Shared.Keybinds['J'], v.name, {
            type = 'client',
            event = 'rsg-delivery:client:vehiclespawn',
            args = { v.deliveryid, v.cart, v.cartspawn, v.cargo, v.light, v.endcoords, v.showgps, v.missiontime },
        })
        if v.showblip == true then
            local DeliveryBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.startcoords)
            SetBlipSprite(DeliveryBlip, GetHashKey(Config.Blip.blipSprite), true)
            SetBlipScale(DeliveryBlip, Config.Blip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, DeliveryBlip, Config.Blip.blipName)
        end
    end
end)

RegisterNetEvent('rsg-delivery:client:vehiclespawn')
AddEventHandler('rsg-delivery:client:vehiclespawn', function(deliveryid, cart, cartspawn, cargo, light, endcoords, showgps, missiontime)
    if wagonSpawned == false then
        local playerPed = PlayerPedId()
        local carthash = GetHashKey(cart)
        local cargohash = GetHashKey(cargo)
        local lighthash = GetHashKey(light)
        local coordsCartSpawn = vector3(cartspawn.x, cartspawn.y, cartspawn.z)
        local coordsEnd = vector3(endcoords.x, endcoords.y, endcoords.z)
        local distance = #(coordsCartSpawn - coordsEnd) 
        local cashreward = (math.floor(distance) / 100)
        
        if Config.Debug == true then
            print('carthash '..carthash)
            print('cargohash '..cargohash)
            print('lighthash '..lighthash)
            print('distance '..distance)
            print('cashreward '..cashreward)
        end
        
        RequestModel(carthash, cargohash, lighthash)
        while not HasModelLoaded(carthash, cargohash, lighthash) do
            RequestModel(carthash, cargohash, lighthash)
            Citizen.Wait(0)
        end
        
        local coords = vector3(cartspawn.x, cartspawn.y, cartspawn.z)
        local heading = cartspawn.w
        local vehicle = CreateVehicle(carthash, coords, heading, true, false)
        SetVehicleOnGroundProperly(vehicle)
        Wait(200)
        SetModelAsNoLongerNeeded(carthash)
        Citizen.InvokeNative(0xD80FAF919A2E56EA, vehicle, cargohash)
        Citizen.InvokeNative(0xC0F0417A90402742, vehicle, lighthash)
        TaskEnterVehicle(playerPed, vehicle, 10000, -1, 1.0, 1, 0)
        if showgps == true then
            StartGpsMultiRoute(GetHashKey("COLOR_RED"), true, true)
            AddPointToGpsMultiRoute(endcoords)
            SetGpsMultiRouteRender(true)
        end
        wagonSpawned = true
        missionactive = true
        MissionTimer(missiontime, vehicle, endcoords)
        while true do
            local sleep = 1000
            if wagonSpawned == true then
                local vehpos = GetEntityCoords(vehicle, true)
                if #(vehpos - endcoords) < 250.0 then
                    sleep = 0
                    DrawText3D(endcoords.x, endcoords.y, endcoords.z + 0.98, Lang:t('label.delivery_point'))
                    if #(vehpos - endcoords) < 3.0 then
                        if showgps == true then
                            ClearGpsMultiRoute(endcoords)
                        end
                        endcoords = nil
                        DeleteVehicle(vehicle)
                        TriggerServerEvent('rsg-delivery:server:givereward', cashreward)
                        wagonSpawned = false
                        missionactive = false
                        lib.notify({ title = Lang:t('success.success_del'), description = Lang:t('success.success_del_descr'), type = 'success' })
                    end
                end
            end
            Wait(sleep)
        end
    end
end)
