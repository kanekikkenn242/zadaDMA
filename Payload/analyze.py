import os, re

target_dir = "Payload/X.app"
output_file = "x_app_analysis.txt"

def extract_strings(filepath, min_length=4):
    with open(filepath, "rb") as f:
        data = f.read()
    pattern = re.compile(rb'[ -~]{' + str(min_length).encode() + rb',}')
    return [m.group(0).decode('ascii', errors='ignore') for m in pattern.finditer(data)]

print("[*] Duke analizuar cdo file ne Payload/X.app...")

with open(output_file, 'w', encoding='utf-8') as out:
    for root, _, files in os.walk(target_dir):
        for file in files:
            filepath = os.path.join(root, file)
            out.write(f"\n\n=== FILE: {filepath} ===\n")
            try:
                strings = extract_strings(filepath)
                # Filtrojme vetem gjerat e rendesishme qe na duhen per te kuptuar çelësin
                keywords = ['http', 'license', 'activation', 'container', 'sandbox', 'MobileHouseArrest', 'NSUserDefaults', 'kfd', 'Xkey', 'key', 'valid', 'status']
                interesting = [s for s in strings if any(k.lower() in s.lower() for k in keywords)]
                out.write("\n".join(interesting) + "\n")
            except Exception:
                pass

print(f"[+] Analiza perfundoi! Hap skedarin {output_file} per te pare rezultatet.")
