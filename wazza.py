import ctypes

libcudart = ctypes.CDLL("/usr/local/cuda-11.8/lib64/libcudart.so.11.0")
count = ctypes.c_int(0)
ret = libcudart.cudaGetDeviceCount(ctypes.byref(count))
print(f"cudaGetDeviceCount: ret={ret}, count={count.value}")

if ret != 0:
    libcudart.cudaGetErrorString.restype = ctypes.c_char_p
    print("Error:", libcudart.cudaGetErrorString(ret).decode())