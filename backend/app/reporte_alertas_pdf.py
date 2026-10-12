from io import BytesIO

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

VERDE = colors.HexColor("#0FBE8B")
ROJO = colors.HexColor("#DC2626")
GRIS = colors.HexColor("#F1F5F4")


def _tabla(filas, anchos=None, color=VERDE):
    tabla = Table(filas, colWidths=anchos, repeatRows=1)
    tabla.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), color),
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


def _fecha(valor) -> str:
    return f"{valor:%d/%m/%Y %H:%M}"


def _fila_alerta(a: dict) -> list:
    return [
        a["pila"],
        a["ubicacion"] or "-",
        a["nombre"],
        f"{a['valor']:g}",
        f"{'max' if a['lado'] == 'maximo' else 'min'} {a['limite']:g}",
        a["sensor_codigo"] or "-",
        _fecha(a["fecha"]),
    ]


ENCABEZADO_ALERTAS = [
    "Pila",
    "Planta",
    "Variable",
    "Valor",
    "Limite",
    "Sensor",
    "Fecha (UTC)",
]
ANCHOS_ALERTAS = [2.7 * cm, 2.8 * cm, 2.7 * cm, 1.6 * cm, 2.0 * cm, 2.6 * cm, 3.0 * cm]


def generar_pdf(resumen: dict, activas: list[dict], recientes: list[dict]) -> bytes:
    """`resumen` viene de alertas_service.resumen_alertas(); `activas` y
    `recientes` de alertas_service.listar_alertas()."""
    estilos = getSampleStyleSheet()
    h2 = estilos["Heading2"]
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=1.8 * cm,
        rightMargin=1.8 * cm,
        topMargin=1.5 * cm,
        bottomMargin=1.5 * cm,
        title="Reporte de alertas SmartCompost",
    )

    historia = [
        Paragraph("SmartCompost - Reporte de alertas", estilos["Title"]),
        Paragraph(
            f"Periodo: <b>{resumen['periodo']}</b> | "
            f"{resumen['desde']:%d/%m/%Y} a {resumen['hasta']:%d/%m/%Y}",
            estilos["Normal"],
        ),
        Spacer(1, 0.4 * cm),
        Paragraph("Resumen", h2),
        _tabla(
            [
                ["Alertas", "Activas", "Lecturas", "Fuera de limite", "% fuera"],
                [
                    str(resumen["total_alertas"]),
                    str(resumen["alertas_activas"]),
                    str(resumen["total_lecturas"]),
                    str(resumen["lecturas_fuera_de_limite"]),
                    f"{resumen['porcentaje_fuera_de_limite']:g} %",
                ],
            ]
        ),
        Spacer(1, 0.3 * cm),
        Paragraph("Alertas activas", h2),
    ]

    if activas:
        filas = [ENCABEZADO_ALERTAS] + [_fila_alerta(a) for a in activas]
        historia.append(_tabla(filas, ANCHOS_ALERTAS, color=ROJO))
    else:
        historia.append(Paragraph("Sin alertas activas.", estilos["Normal"]))

    historia += [Spacer(1, 0.3 * cm), Paragraph("Alertas por variable", h2)]
    if resumen["por_variable"]:
        filas = [["Variable", "Alertas"]] + [
            [v["nombre"], str(v["total"])] for v in resumen["por_variable"]
        ]
        historia.append(_tabla(filas, [8 * cm, 4 * cm]))
    else:
        historia.append(Paragraph("Sin alertas en el periodo.", estilos["Normal"]))

    historia += [Spacer(1, 0.3 * cm), Paragraph("Alertas por pila", h2)]
    if resumen["por_pila"]:
        filas = [["Pila", "Planta", "Alertas"]] + [
            [p["pila"], p["ubicacion"] or "-", str(p["total"])]
            for p in resumen["por_pila"]
        ]
        historia.append(_tabla(filas, [6 * cm, 6 * cm, 3 * cm]))
    else:
        historia.append(Paragraph("Sin alertas en el periodo.", estilos["Normal"]))

    historia += [Spacer(1, 0.3 * cm), Paragraph("Alertas por sensor", h2)]
    if resumen["por_sensor"]:
        filas = [["Sensor", "Tipo", "Pila", "Alertas"]] + [
            [s["codigo"], s["tipo"], s["pila"], str(s["total"])]
            for s in resumen["por_sensor"]
        ]
        historia.append(_tabla(filas, [4.5 * cm, 3.5 * cm, 5 * cm, 3 * cm]))
    else:
        historia.append(Paragraph("Sin alertas en el periodo.", estilos["Normal"]))

    historia += [
        Spacer(1, 0.3 * cm),
        Paragraph(f"Historial reciente (ultimas {len(recientes)})", h2),
    ]
    if recientes:
        filas = [ENCABEZADO_ALERTAS] + [_fila_alerta(a) for a in recientes]
        historia.append(_tabla(filas, ANCHOS_ALERTAS))
    else:
        historia.append(Paragraph("Sin alertas en el periodo.", estilos["Normal"]))

    doc.build(historia)
    return buffer.getvalue()
