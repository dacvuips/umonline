import struct

with open('Client/Data/Item/Bow07.bmd', 'rb') as f:
    data = f.read()

# BMD header: 3 bytes "BMD" or encrypted
# Let's check mu_convert_all.py to see how BMD is parsed
print("Length:", len(data))
print("First 16 bytes:", data[:16])
