#!/usr/bin/env python3
"""Busca nodos de accesibilidad en un volcado de uiautomator.
Uso: ui_nodes.py archivo.xml exact|prefix|contains TEXTO
Imprime una línea por nodo: clase|clickable|selected|checked|cx|cy|content-desc (primeros 90 car.)."""
import re, sys
import xml.etree.ElementTree as ET

path, mode, text = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    root = ET.parse(path).getroot()
except Exception as e:
    print(f"ERROR|{e}")
    sys.exit(0)
for n in root.iter('node'):
    label = (n.get('content-desc') or '') or (n.get('text') or '')
    ok = (mode == 'exact' and label == text) or (mode == 'prefix' and label.startswith(text)) or \
         (mode == 'contains' and text in label)
    if not ok:
        continue
    m = re.findall(r'\d+', n.get('bounds', ''))
    cx = cy = -1
    if len(m) == 4:
        x1, y1, x2, y2 = map(int, m)
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
    flat = label.replace('\n', ' / ')[:90]
    print(f"{n.get('class')}|{n.get('clickable')}|{n.get('selected')}|{n.get('checked')}|{cx}|{cy}|{flat}")
