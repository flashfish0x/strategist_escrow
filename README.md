# Yearn Strategist Escrow

This contract acts as an intermidiary contract for holding YFI before the veYFI contracts are finished. 

Each strategist has an escrow that hold the YFI that would be locked if they chose max duration for their buyout. 

Once in escrow the strategist can either wait for the escrow period to expire and claim their yfi. Or if both strategist and ychad agree the escrow can be migrated to a new contract. The expectation is that these escrows will be migrated to veYFI when that is ready.