import os

file_path = "Payload/X.app/X"

if not os.path.exists(file_path):
    print("[-] Skedari X nuk u gjet. Kontrollo rrugen.")
    exit(1)

print("[*] Duke lexuar binarin X...")
with open(file_path, "rb") as f:
    data = bytearray(f.read())

# 1. Ndryshojme URL-ne e serverit qe app-i te mos lidhet me te
old_url = b"https://xkeyapi.onrender.com"
# Krijojme nje URL tjeter me te njejten gjatesi (e mbushim me zero)
new_url = b"http://127.0.0.1:9999" + b"\x00" * (len(old_url) - len(b"http://127.0.0.1:9999"))

if old_url in data:
    data = data.replace(old_url, new_url)
    print("[+] URL e serverit u patch-ua.")
else:
    print("[-] URL nuk u gjet.")

# 2. Ndryshojme tekstin 'activation_granted' qe app-i te mos e gjeje
old_key = b"activation_granted"
new_key = b"activation_bypassed"  # e njejta gjatesi (18 shkronja)

if old_key in data:
    data = data.replace(old_key, new_key)
    print("[+] Teksti i çelësit u patch-ua.")
else:
    print("[-] Teksti i çelësit nuk u gjet.")

with open(file_path, "wb") as f:
    f.write(data)

print("[+] Binar i patch-uar me sukses!")
print("[*] Tani duhet ta paketosh ne IPA dhe ta firmosesh me eSign.")
