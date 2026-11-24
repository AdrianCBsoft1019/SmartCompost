"""Procesa la foto de perfil subida por el usuario.

Se valida que sea una imagen real (no se confia en la extension ni en el
Content-Type), se corrige la rotacion EXIF, se recorta a cuadrado y se
reduce a 256x256 en JPEG para que ocupe poco espacio en la base de datos
(unos 10-20 KB; en PNG una foto real pesaba ~100 KB y no cabia en un BLOB
de MySQL/TiDB, que admite maximo 64 KB).
"""

from io import BytesIO

from PIL import Image, ImageOps

MAX_BYTES = 5 * 1024 * 1024  # 5 MB como maximo de subida
MAX_PIXELES = 40_000_000  # evita imagenes gigantes que agoten la memoria
LADO = 256
FORMATOS = {"PNG", "JPEG", "WEBP"}
TIPO_SALIDA = "image/jpeg"
CALIDAD_JPEG = 85


def procesar_imagen(datos: bytes) -> bytes:
    """Devuelve la imagen como JPEG cuadrado de 256x256 o lanza ValueError."""
    if not datos:
        raise ValueError("No se recibio ningun archivo")
    if len(datos) > MAX_BYTES:
        raise ValueError("La imagen supera el maximo de 5 MB")
    try:
        with Image.open(BytesIO(datos)) as img:
            if img.format not in FORMATOS:
                raise ValueError("Formato no permitido: usa PNG, JPG o WEBP")
            if img.width * img.height > MAX_PIXELES:
                raise ValueError("La imagen es demasiado grande en pixeles")
            img = ImageOps.exif_transpose(img).convert("RGBA")
            img = ImageOps.fit(img, (LADO, LADO), Image.Resampling.LANCZOS)
            # JPEG no tiene transparencia: se pone sobre fondo blanco.
            fondo = Image.new("RGB", img.size, (255, 255, 255))
            fondo.paste(img, mask=img.getchannel("A"))
            salida = BytesIO()
            fondo.save(salida, format="JPEG", quality=CALIDAD_JPEG, optimize=True)
            return salida.getvalue()
    except ValueError:
        raise
    except Exception as exc:  # archivo corrupto, no es imagen, etc.
        raise ValueError("El archivo no es una imagen valida") from exc
