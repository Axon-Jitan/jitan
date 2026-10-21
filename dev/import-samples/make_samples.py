"""Writes the Import employees sample files in this folder (development data
only: names start with [DEV], codes with DEVIMP).

    python -I dev/import-samples/make_samples.py [prefix]

A code can be imported once; to import the same rows again, run this with
another prefix (e.g. DEVIMP2) and use the new files.
"""
import csv
import os
import sys

from openpyxl import Workbook
from openpyxl.styles import Font

HERE = os.path.dirname(os.path.abspath(__file__))
PREFIX = sys.argv[1] if len(sys.argv) > 1 else 'DEVIMP'
HEADER = ['First name', 'Last name', 'Employee code', 'Phone', 'Email', 'Groups']

READY = [
    ['[DEV] Anna', 'Peeters', f'{PREFIX}01', '+32470123456', 'anna.peeters@example.com', 'Blue collar'],
    ['[DEV] Bram', 'Janssens', f'{PREFIX}02', '+32 471 22 10 98', '', 'Blue collar'],
    ['[DEV] Chloé', 'Maes', f'{PREFIX}03', '', 'chloe.maes@example.com', 'White collar'],
    ['[DEV] Dries', 'Jacobs', f'{PREFIX}04', '+32 472 80 11 02', '', 'Blue collar; White collar'],
    ['[DEV] Elise', 'Willems', f'{PREFIX}05', '+31 6 12345678', 'elise.willems@example.com', 'White collar'],
    ['[DEV] Finn', 'Claes', f'{PREFIX}06', '+256 772 123456', '', 'Blue collar'],
    ['[DEV] Greet', 'Wouters', f'{PREFIX}07', '', '', ''],
    ['[DEV] Hanne', 'Goossens', f'{PREFIX}08', '+44 20 7946 0958', 'hanne.goossens@example.com', 'White collar'],
    ['[DEV] Ilias', 'De Smet', f'{PREFIX}09', '+32 473 45 67 89', '', 'Blue collar'],
    ['[DEV] Jana', 'Vermeulen', f'{PREFIX}10', '+32 474 98 76 54', 'jana.vermeulen@example.com', 'White collar'],
]

# Three good rows, then one row for each problem the preview reports.
PROBLEMS = [
    ['[DEV] Karel', 'Pauwels', f'{PREFIX}11', '+32 475 11 22 33', '', 'Blue collar'],
    ['[DEV] Lotte', 'Hermans', f'{PREFIX}12', '', 'lotte.hermans@example.com', 'White collar'],
    ['[DEV] Mats', 'Michiels', f'{PREFIX}13', '+32 476 44 55 66', '', ''],
    ['[DEV] Nina', '', f'{PREFIX}14', '', '', 'Blue collar'],                        # Last name is missing
    ['[DEV] Olivier', 'Lambrechts', '', '', '', 'Blue collar'],                       # Employee code is missing
    ['[DEV] Pieter', 'Aerts', 'SBW', '', '', 'White collar'],                         # Code SBW is already used
    ['[DEV] Quinten', 'Martens', f'{PREFIX}11', '', '', 'Blue collar'],              # Same code as row 2
    ['[DEV] Roos', 'Segers', f'{PREFIX}15', '', '', 'Cleaners'],                     # No group called Cleaners
    ['[DEV] Sander', 'Wuyts', f'{PREFIX}16', '0470 12 34 56', '', 'Blue collar'],    # Phone needs + and the country code
    ['[DEV] Tine', 'Mertens', f'{PREFIX}17', '+32 4ab 12', '', 'White collar'],       # Phone number is not valid
    ['[DEV] Ward', 'Dubois', f'{PREFIX}18', '+3247', '', 'Blue collar'],             # Phone number is not valid
    ['[DEV] Xena', 'Lemmens', f'{PREFIX}19', '', 'xena.lemmens.example.com', ''],    # Email is not valid
]


def xlsx(name, header, rows):
    book = Workbook()
    sheet = book.active
    sheet.title = 'Employees'
    sheet.append(header)
    for cell in sheet[1]:
        cell.font = Font(bold=True)
    for row in rows:
        # Phones and codes as text, so Excel keeps the + and leading zeros.
        sheet.append([str(v) for v in row])
    for column, width in zip('ABCDEF', [18, 16, 16, 20, 30, 26]):
        sheet.column_dimensions[column].width = width
    book.save(os.path.join(HERE, name))


def write_csv(name, header, rows, delimiter):
    with open(os.path.join(HERE, name), 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f, delimiter=delimiter)
        writer.writerow(header)
        writer.writerows(rows)


xlsx('employees-ready.xlsx', HEADER, READY)
write_csv('employees-ready.csv', HEADER, READY, ';')            # Belgian Excel style
xlsx('employees-with-problems.xlsx', HEADER, PROBLEMS)
write_csv('employees-with-problems.csv', HEADER, PROBLEMS, ',')  # comma style
write_csv('employees-missing-column.csv', ['First name', 'Last name', 'Phone'], [r[:2] + [r[3]] for r in READY[:3]], ';')
print('written to', HERE)
