﻿--[[ Time (in seconds) required to enter a vehicle ]]
SimfphysCompatibility.TimeToEnterVehicle = 1
--[[ If Car Entry Delay is Applicable ]]
SimfphysCompatibility.CarEntryDelayEnabled = true
--[[ Indicates whether damage while in cars is enabled   ]]
SimfphysCompatibility.DamageInCars = true
--[[ Valid Damages When DMGing a Car]]
SimfphysCompatibility.ValidCarDamages = {DMG_VEHICLE, DMG_BULLET}
--[[ Console Commands To Be Ran on Initialize ]]
SimfphysCompatibility.SimfphysConsoleCommands = {
    ["sv_simfphys_gib_lifetime"] = "0",
    ["sv_simfphys_fuel"] = "0",
    ["sv_simfphys_traction_snow"] = "1",
    ["sv_simfphys_damagemultiplicator"] = "100",
}
