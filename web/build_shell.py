import base64, pathlib
d = pathlib.Path(__file__).parent
b64 = base64.b64encode((d/'mu_logo.png').read_bytes()).decode()
(d/'mu_shell.html').write_text((d/'mu_shell.src.html').read_text(encoding='utf-8').replace('__MU_LOGO_B64__', b64), encoding='utf-8')
print('ok')
