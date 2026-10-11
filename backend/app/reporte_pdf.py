"""Genera el PDF descargable de la Vista de Analisis con reportlab."""

from io import BytesIO

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

VERDE = colors.HexColor("#0FBE8B")
GRIS = colors.HexColor("#F1F5F4")


def _num(valor, sufijo=""):
    return "-" if valor is None else f"{valor:g}{sufijo}"


def _tabla(filas, anchos=None):
    tabla = Table(filas, colWidths=anchos, repeatRows=1)
    tabla.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), VERDE),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8.5),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, GRIS]),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#CBD5D1")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )
    return tabla


def generar_pdf(datos: dict) -> bytes:
    """`datos` es el dict que devuelve analisis_service.resumen()."""
    estilos = getSampleStyleSheet()
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.5 * cm,
        bottomMargin=1.5 * cm,
        title="Reporte de analisis SmartCompost",
    )
    h2 = estilos["Heading2"]
    historia = [
        Paragraph("SmartCompost - Reporte de analisis", estilos["Title"]),
        Paragraph(
            f"Periodo: <b>{datos['periodo']}</b> | "
            f"{datos['desde']:%d/%m/%Y} a {datos['hasta']:%d/%m/%Y} | "
            f"Lecturas analizadas: {datos['total_lecturas']}",
            estilos["Normal"],
        ),
        Spacer(1, 0.4 * cm),
        Paragraph("Promedios del periodo", h2),
    ]

    p = datos["promedios"]
    historia.append(
        _tabla(
            [
                ["Temperatura", "Humedad", "CO2", "CH4", "NH3"],
                [
                    _num(p["temperatura"], " C"),
                    _num(p["humedad"], " %"),
                    _num(p["co2_ppm"], " ppm"),
                    _num(p["ch4_ppm"], " ppm"),
                    _num(p["nh3_ppm"], " ppm"),
                ],
            ]
        )
    )

    historia += [Spacer(1, 0.3 * cm), Paragraph("Comparativa de pilas", h2)]
    filas = [
        ["Pila", "Planta", "Fase", "Estado", "T prom", "T max", "Hum", "Fuera lim."]
    ]
    for c in datos["comparativa"]:
        filas.append(
            [
                c["nombre"],
                c["ubicacion"] or "-",
                c["fase"],
                c["estado"],
                _num(c["temperatura_prom"]),
                _num(c["temperatura_max"]),
                _num(c["humedad_prom"]),
                str(c["lecturas_fuera_limite"]),
            ]
        )
    historia.append(_tabla(filas))

    historia += [Spacer(1, 0.3 * cm), Paragraph("Alertas activas", h2)]
    if datos["alertas_activas"]:
        filas = [["Pila", "Detalle"]] + [
            [a["pila"], a["mensaje"]] for a in datos["alertas_activas"]
        ]
        historia.append(_tabla(filas, [4 * cm, 13 * cm]))
    else:
        historia.append(Paragraph("Sin alertas activas.", estilos["Normal"]))

    historia += [Spacer(1, 0.3 * cm), Paragraph("Tendencia semanal de gases", h2)]
    filas = [["Fecha", "CO2 (ppm)", "CH4 (ppm)", "NH3 (ppm)"]]
    for t in datos["tendencia_semanal"]:
        filas.append(
            [t["fecha"], _num(t["co2_ppm"]), _num(t["ch4_ppm"]), _num(t["nh3_ppm"])]
        )
    historia.append(_tabla(filas))

    historia += [Spacer(1, 0.3 * cm), Paragraph("Sensores por planta", h2)]
    filas = [["Planta", "Sensor", "Tipo", "Pila", "Estado", "Alteraciones"]]
    for planta in datos["sensores_por_planta"]:
        for s in planta["sensores"]:
            filas.append(
                [
                    planta["planta"],
                    s["codigo"],
                    s["tipo"],
                    s["pila"],
                    "activo" if s["activo"] else "inactivo",
                    str(s["alteraciones"]),
                ]
            )
    historia.append(_tabla(filas))

    doc.build(historia)
    return buffer.getvalue()
