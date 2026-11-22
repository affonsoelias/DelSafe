import ctypes
import os
import sys

# Carrega a DLL gerada pelo Aether (aether_math.dll)
dll_path = os.path.join(os.path.dirname(__file__), "bin", "aether_math.dll")
if not os.path.exists(dll_path):
    print(f"Erro: DLL nao encontrada em {dll_path}")
    sys.exit(1)

lib = ctypes.CDLL(dll_path)

# Define a struct Ponto2D correspondente
class Ponto2D(ctypes.Structure):
    _fields_ = [
        ("x", ctypes.c_double),
        ("y", ctypes.c_double)
    ]

# Configura assinaturas das funcoes exportadas do Aether
lib.SomarInteiros.argtypes = [ctypes.c_int32, ctypes.c_int32]
lib.SomarInteiros.restype = ctypes.c_int32

lib.MultiplicarInteiros.argtypes = [ctypes.c_int32, ctypes.c_int32]
lib.MultiplicarInteiros.restype = ctypes.c_int32

lib.CriarPonto.argtypes = [ctypes.c_double, ctypes.c_double]
lib.CriarPonto.restype = Ponto2D

lib.SomarPontos.argtypes = [Ponto2D, Ponto2D]
lib.SomarPontos.restype = Ponto2D

lib.NormaAoQuadrado.argtypes = [Ponto2D]
lib.NormaAoQuadrado.restype = ctypes.c_double

# 1. Teste de inteiros
res_soma = lib.SomarInteiros(15, 27)
print(f"[Python ctypes] SomarInteiros(15, 27) = {res_soma}")
assert res_soma == 42, f"Esperado 42, obtido {res_soma}"

res_mult = lib.MultiplicarInteiros(6, 7)
print(f"[Python ctypes] MultiplicarInteiros(6, 7) = {res_mult}")
assert res_mult == 42, f"Esperado 42, obtido {res_mult}"

# 2. Teste com structs Ponto2D
p1 = lib.CriarPonto(3.0, 4.0)
print(f"[Python ctypes] CriarPonto(3.0, 4.0) -> ({p1.x}, {p1.y})")
assert p1.x == 3.0 and p1.y == 4.0

p2 = lib.CriarPonto(1.0, 2.0)
p3 = lib.SomarPontos(p1, p2)
print(f"[Python ctypes] SomarPontos(p1, p2) -> ({p3.x}, {p3.y})")
assert p3.x == 4.0 and p3.y == 6.0

norma = lib.NormaAoQuadrado(p1)
print(f"[Python ctypes] NormaAoQuadrado(p1) -> {norma}")
assert norma == 25.0, f"Esperado 25.0, obtido {norma}"

print("\n>>> SUCESSO! Todos os testes de FFI Python -> Aether DLL passaram com 100% de precisao! <<<")
