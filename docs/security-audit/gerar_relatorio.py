#!/usr/bin/env python3
"""Gera o relatório estático da auditoria de segurança do gabaritei_app.

Dependências isoladas: reportlab, matplotlib e pymupdf.
Exemplo:
  python -m venv .venv
  .venv/Scripts/python -m pip install reportlab matplotlib pymupdf
  .venv/Scripts/python docs/security-audit/gerar_relatorio.py
"""
from __future__ import annotations

import argparse
import tempfile
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pymupdf

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, mm
from reportlab.platypus import (
    BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, PageBreak,
    Image, Table, TableStyle, Preformatted, HRFlowable, KeepTogether,
)
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).with_name("relatorio-auditoria-seguranca.pdf")
REPORT_NAME = "Relatório de Auditoria de Segurança — gabaritei_app"
AUDIT_DATE = "11 de novembro de 2026"
PROJECT = "Projeto Gabaritei Questões"
PROJECT_REF = "ivhuaevrrkrnagbqmnwc"

PALETTE = {
    "Crítica": "#B91C1C",
    "Alta": "#EA580C",
    "Média": "#D97706",
    "Baixa": "#2563EB",
    "Ponto forte": "#059669",
    "navy": "#0F172A",
    "slate": "#334155",
    "muted": "#64748B",
    "line": "#CBD5E1",
    "pale": "#F8FAFC",
    "green_pale": "#ECFDF5",
    "amber_pale": "#FFFBEB",
}

CATEGORIES = [
    "Banco sem tranca",
    "Permissão no navegador",
    "IDOR",
    "Chaves expostas",
    "Inputs sem tratamento (XSS)",
]

FINDINGS = [
    {
        "id": "F-01",
        "category": "Banco sem tranca",
        "severity": "Média",
        "location": (
            "Supabase remoto: policies das tabelas explicacoes_ia, ia_cache_estudo, "
            "feedbacks_ia e feedbacks_questoes; lib/repositories/study_ai_repository.dart: "
            "58–60, 110–124, 173–180, 238–244, 318–326; "
            "lib/repositories/question_repository.dart: 407–411."
        ),
        "description": (
            "As policies dessas tabelas globais usam somente eh_app_aluno(), sem "
            "auth.uid(), dono ou papel administrativo. A função aceita um token "
            "estático enviado pelo cliente. Assim, clientes anon podem ler feedbacks "
            "e semear conteúdo global de IA; ia_cache_estudo não tem unicidade por "
            "questão/tipo e a UI lê com maybeSingle(). Os feedbacks tinham 0 linhas "
            "na consulta; explicacoes_ia tinha 160 e ia_cache_estudo 52."
        ),
        "condition": (
            "A leitura de feedback só expõe conteúdo se houver linhas. O envenenamento "
            "atinge questões sem explicação existente; duplicatas no cache podem fazer "
            "maybeSingle() falhar. O token usado na policy é recuperável do app."
        ),
    },
    {
        "id": "F-02",
        "category": "Chaves expostas",
        "severity": "Média",
        "location": (
            "env.json:4; lib/core/config/app_config.dart:20; lib/main.dart:196; "
            "função remota public.eh_app_aluno()."
        ),
        "description": (
            "APP_TOKEN contém um valor real no ambiente local, é compilado por "
            "String.fromEnvironment e enviado em x-app-token em toda conexão Supabase. "
            "A função RLS remota compara esse cabeçalho com o mesmo valor literal. "
            "O .gitignore exclui env.json, mas isso não protege o segredo do APK/IPA."
        ),
        "condition": (
            "A chave publishable do Supabase não é um segredo e não foi classificada "
            "como falha. O token APP_TOKEN não é service_role e as policies de dados "
            "pessoais continuam exigindo posse; o risco confirmado é contornar o gate "
            "de cliente das tabelas globais descritas em F-01."
        ),
    },
    {
        "id": "F-03",
        "category": "Chaves expostas",
        "severity": "Baixa",
        "location": "opencode.json:9.",
        "description": (
            "A configuração ativa do Stitch MCP contém um valor literal no cabeçalho "
            "X-Goog-Api-Key. A chave está presente no checkout e não aparece mascarada "
            "como placeholder."
        ),
        "condition": (
            "Validade, escopo e restrições da chave não foram confirmados. O impacto "
            "depende de a chave ainda estar ativa e permitir uso fora do ambiente local."
        ),
    },
]

ISSUE_1 = """--- ISSUE 1 ---
# [Segurança] Remover APP_TOKEN do cliente e restringir RLS de cache/feedback

Labels sugeridas: security, severity:medium

## Descrição do problema
O app compila APP_TOKEN como constante e envia o valor no cabeçalho x-app-token. No Supabase, public.eh_app_aluno() compara esse cabeçalho com um valor literal. Policies de explicacoes_ia, ia_cache_estudo, feedbacks_ia e feedbacks_questoes usam essa função como única condição, sem validar auth.uid(), dono ou papel administrativo.

Como o valor está no cliente distribuído, qualquer pessoa pode extraí-lo e chamar o PostgREST diretamente com a chave publishable. Isso permite ler feedbacks internos (quando houver linhas) e inserir conteúdo em caches globais. Em ia_cache_estudo não há restrição única por id_questao/tipo; duplicatas também podem quebrar consultas maybeSingle(). O app consulta explicacoes_ia antes de exigir a chave BYOK.

## Evidência
- env.json:4: APP_TOKEN contém um token real (valor omitido neste reporte).
- lib/core/config/app_config.dart:20: appToken: String.fromEnvironment('APP_TOKEN')
- lib/main.dart:196: headers: {'x-app-token': config.appToken}
- Supabase remoto, public.eh_app_aluno(): compara request.headers['x-app-token'] com o token estático correspondente.
- Policies remotas anon_le_explicacoes, anon_grava_explicacoes, anon_le_cache_ia, anon_grava_cache_ia, anon_le_feedbacks_ia, anon_reporta_feedback_ia, anon_le_feedbacks e anon_reporta_feedback usam somente eh_app_aluno(). Não há arquivo de migration SQL no checkout; a evidência é o estado remoto consultado.
- lib/repositories/study_ai_repository.dart:58-60, 173-180 e 238-244: leitura e gravação de cache global.
- lib/repositories/question_repository.dart:407-411: grava relato de feedback sem identidade de dono.

## Impacto
A fronteira de “cliente oficial” é falsificável; dados de feedback podem ser lidos por qualquer cliente que obtenha o token, e conteúdo global de IA pode ser semeado/duplicado para afetar outros usuários. Não foi observado acesso cruzado às tabelas pessoais: suas policies de dono continuam vinculadas a auth.uid().

## Sugestão de correção
Remover APP_TOKEN do Flutter e deixar de tratá-lo como segredo. Para dados pessoais, usar policies vinculadas a auth.uid() e à linha de dono. Para caches globais, permitir leitura pública apenas se intencional e mover gravações para uma Edge Function autenticada, com validação de origem, autorização e rate limit. Restringir SELECT de feedbacks a administrador/service role. Criar unicidade em ia_cache_estudo(id_questao, tipo) e definir política de escrita confiável para explicacoes_ia.

## Critérios de aceite
- [ ] Nenhum APP_TOKEN ou outro segredo compartilhado aparece no APK/IPA ou nos dart-defines do cliente.
- [ ] Cliente anon com a chave publishable não consegue listar feedbacks nem inserir cache global.
- [ ] Usuário A não consegue ler ou alterar dados privados do usuário B, mesmo manipulando IDs.
- [ ] Escritas de cache são autenticadas/validadas no servidor e duplicatas por questão/tipo são rejeitadas.
- [ ] Testes RLS cobrem anon, usuário A, usuário B, dados de feedback e conteúdo de cache.
- [ ] As policies e testes ficam versionados em migrations do projeto.
--- FIM ISSUE 1 ---"""

ISSUE_2 = """--- ISSUE 2 ---
# [Segurança] Retirar chave Google estática da configuração do OpenCode

Labels sugeridas: security, severity:low

## Descrição do problema
opencode.json contém uma chave literal no cabeçalho X-Goog-Api-Key da conexão remota do Stitch MCP. O valor foi redigido deste reporte. A validade e as restrições não foram verificadas.

## Por que é explorável
Se a chave ainda estiver ativa e sem restrição adequada, qualquer pessoa que obtenha esse arquivo pode reutilizar a credencial, consumir quota ou acessar a API associada. O arquivo não está coberto pelas regras de exclusão de env.json; o checkout, porém, não contém metadados Git para confirmar se foi commitado.

## Evidência
- opencode.json:9: X-Goog-Api-Key: valor literal com formato de credencial (redigido).
- opencode.json mantém a conexão Stitch remota habilitada.

## Impacto
Uso indevido de quota/serviço Google associado à chave, condicionado à validade e às restrições configuradas pelo proprietário.

## Sugestão de correção
Revogar e rotacionar a chave se ainda estiver ativa. Guardá-la em configuração local não versionada ou em armazenamento de segredos apropriado, aplicar restrições de API/quota e evitar credenciais pessoais em arquivos distribuídos com o projeto.

## Critérios de aceite
- [ ] opencode.json não contém valor de chave literal.
- [ ] A chave antiga foi revogada/rotacionada se estava ativa.
- [ ] A nova credencial tem restrição de API e quota mínima necessária.
- [ ] O histórico Git, quando disponível, foi verificado e qualquer chave exposta foi revogada.
--- FIM ISSUE 2 ---"""


def hx(value: str) -> colors.Color:
    return colors.HexColor(value)


def make_styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle(
        name="BodyPT", parent=s["BodyText"], fontName="Helvetica",
        fontSize=9.1, leading=13.2, textColor=hx(PALETTE["slate"]),
        spaceAfter=6, alignment=TA_LEFT,
    ))
    s.add(ParagraphStyle(
        name="SmallPT", parent=s["BodyText"], fontName="Helvetica",
        fontSize=7.5, leading=10, textColor=hx(PALETTE["muted"]),
        spaceAfter=3,
    ))
    s.add(ParagraphStyle(
        name="MonoPT", parent=s["BodyText"], fontName="Courier",
        fontSize=7.8, leading=10.2, textColor=hx(PALETTE["slate"]),
        wordWrap="CJK",
    ))
    s.add(ParagraphStyle(
        name="CoverTitlePT", parent=s["Title"], fontName="Helvetica-Bold",
        fontSize=25, leading=31, textColor=hx(PALETTE["navy"]),
        spaceAfter=12,
    ))
    s.add(ParagraphStyle(
        name="CoverProjectPT", parent=s["BodyText"], fontName="Helvetica-Bold",
        fontSize=11, leading=15, textColor=hx(PALETTE["muted"]),
        spaceAfter=8,
    ))
    s.add(ParagraphStyle(
        name="H1PT", parent=s["Heading1"], fontName="Helvetica-Bold",
        fontSize=17, leading=21, textColor=hx(PALETTE["navy"]),
        spaceBefore=4, spaceAfter=10,
    ))
    s.add(ParagraphStyle(
        name="H2PT", parent=s["Heading2"], fontName="Helvetica-Bold",
        fontSize=11.5, leading=15, textColor=hx(PALETTE["slate"]),
        spaceBefore=8, spaceAfter=5,
    ))
    s.add(ParagraphStyle(
        name="TableHeadPT", parent=s["BodyText"], fontName="Helvetica-Bold",
        fontSize=7.6, leading=9, textColor=colors.white,
    ))
    s.add(ParagraphStyle(
        name="TablePT", parent=s["BodyText"], fontName="Helvetica",
        fontSize=8.0, leading=10.7, textColor=hx(PALETTE["slate"]),
    ))
    s.add(ParagraphStyle(
        name="TableMonoPT", parent=s["BodyText"], fontName="Courier",
        fontSize=7.2, leading=9.4, textColor=hx(PALETTE["slate"]),
        wordWrap="CJK",
    ))
    s.add(ParagraphStyle(
        name="ChipPT", parent=s["BodyText"], fontName="Helvetica-Bold",
        fontSize=7.4, leading=9, textColor=colors.white, alignment=TA_CENTER,
    ))
    s.add(ParagraphStyle(
        name="CalloutPT", parent=s["BodyText"], fontName="Helvetica",
        fontSize=8.6, leading=12, textColor=hx(PALETTE["slate"]),
        spaceAfter=0,
    ))
    s.add(ParagraphStyle(
        name="CenterSmallPT", parent=s["BodyText"], fontName="Helvetica",
        fontSize=8, leading=10, textColor=hx(PALETTE["muted"]),
        alignment=TA_CENTER,
    ))
    return s


STYLES = make_styles()


def para(text: str, style: str = "BodyPT") -> Paragraph:
    return Paragraph(text, STYLES[style])


def plain(text: str, style: str = "BodyPT") -> Paragraph:
    return para(escape(text), style)


def draw_page_chrome(canvas, doc):
    canvas.saveState()
    width, height = A4
    canvas.setStrokeColor(hx(PALETTE["line"]))
    canvas.setLineWidth(0.45)
    canvas.line(20 * mm, height - 14 * mm, width - 20 * mm, height - 14 * mm)
    canvas.setFont("Helvetica-Bold", 7.2)
    canvas.setFillColor(hx(PALETTE["slate"]))
    canvas.drawString(20 * mm, height - 11.5 * mm, "GABARITEI_APP  |  AUDITORIA DE SEGURANÇA")
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(hx(PALETTE["muted"]))
    canvas.line(20 * mm, 14 * mm, width - 20 * mm, 14 * mm)
    canvas.drawString(20 * mm, 9.5 * mm, "Relatório de Auditoria de Segurança — gabaritei_app")
    canvas.drawRightString(width - 20 * mm, 9.5 * mm, f"Página {doc.page}")
    canvas.restoreState()


def chart_severity(path: Path):
    values = {key: sum(1 for f in FINDINGS if f["severity"] == key)
              for key in ("Crítica", "Alta", "Média", "Baixa")}
    nonzero = [(name, count) for name, count in values.items() if count]
    fig, ax = plt.subplots(figsize=(5.0, 3.2), dpi=180)
    fig.patch.set_facecolor("white")
    if nonzero:
        labels = [f"{name} — {count}" for name, count in nonzero]
        colors_list = [PALETTE[name] for name, _ in nonzero]
        wedges, _ = ax.pie(
            [count for _, count in nonzero], startangle=90,
            colors=colors_list, wedgeprops={"width": 0.36, "edgecolor": "white", "linewidth": 2},
        )
        ax.text(0, 0.08, str(len(FINDINGS)), ha="center", va="center",
                fontsize=23, fontweight="bold", color=PALETTE["navy"])
        ax.text(0, -0.18, "achados", ha="center", va="center",
                fontsize=9, color=PALETTE["muted"])
        ax.legend(wedges, labels, loc="center left", bbox_to_anchor=(0.92, 0.5),
                  frameon=False, fontsize=9, labelspacing=1.1)
    else:
        ax.text(0.5, 0.5, "Nenhum achado", ha="center", va="center", color=PALETTE["muted"])
    ax.set(aspect="equal")
    ax.axis("off")
    fig.tight_layout(pad=1.0)
    fig.savefig(path, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def chart_categories(path: Path):
    counts = [sum(1 for f in FINDINGS if f["category"] == cat) for cat in CATEGORIES]
    fig, ax = plt.subplots(figsize=(6.0, 3.4), dpi=180)
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")
    bars = ax.barh(range(len(CATEGORIES)), counts, color=PALETTE["slate"], height=0.58)
    ax.set_yticks(range(len(CATEGORIES)))
    ax.set_yticklabels(CATEGORIES, fontsize=8.5, color=PALETTE["slate"])
    ax.invert_yaxis()
    ax.set_xlim(0, max(3, max(counts, default=0) + 1))
    ax.xaxis.grid(True, color="#E2E8F0", linewidth=0.7)
    ax.set_axisbelow(True)
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.spines["bottom"].set_color("#CBD5E1")
    ax.tick_params(axis="x", labelsize=8, colors=PALETTE["muted"], length=0)
    ax.tick_params(axis="y", length=0, pad=7)
    for bar, count in zip(bars, counts):
        ax.text(max(0.08, count + 0.08), bar.get_y() + bar.get_height() / 2,
                str(count), va="center", ha="left", fontsize=9,
                color=PALETTE["navy"], fontweight="bold")
    ax.set_xlabel("Achados confirmados", fontsize=8, color=PALETTE["muted"], labelpad=7)
    fig.tight_layout(pad=1.0)
    fig.savefig(path, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def finding_table(category: str):
    findings = [f for f in FINDINGS if f["category"] == category]
    header = [para("Severidade", "TableHeadPT"), para("Arquivo:linha / origem", "TableHeadPT"),
              para("Descrição", "TableHeadPT")]
    rows = [header]
    if not findings:
        rows.append([
            para("—", "TablePT"),
            para("Não aplicável / sem falha confirmada", "TablePT"),
            para("A cobertura desta categoria e os controles corretos estão descritos na seção de pontos fortes.", "TablePT"),
        ])
    else:
        for finding in findings:
            severity = finding["severity"]
            rows.append([
                para(severity.upper(), "ChipPT"),
                para(escape(finding["location"]), "TableMonoPT"),
                para(escape(finding["description"]), "TablePT"),
            ])
    table = Table(rows, colWidths=[0.78 * inch, 2.12 * inch, 3.72 * inch], repeatRows=1,
                  hAlign="LEFT", splitByRow=1)
    commands = [
        ("BACKGROUND", (0, 0), (-1, 0), hx(PALETTE["navy"])),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.35, hx(PALETTE["line"])),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("BACKGROUND", (1, 1), (-1, -1), colors.white),
    ]
    if findings:
        for row_index, finding in enumerate(findings, start=1):
            commands.append(("BACKGROUND", (0, row_index), (0, row_index), hx(PALETTE[finding["severity"]])))
    else:
        commands.append(("BACKGROUND", (0, 1), (-1, 1), hx(PALETTE["pale"])))
    table.setStyle(TableStyle(commands))
    return table


def bullet(text: str, strong: str | None = None):
    if strong:
        return para(f"<font color='{PALETTE['Ponto forte']}'>●</font> <b>{escape(strong)}</b> {escape(text)}")
    return para(f"<font color='{PALETTE['Ponto forte']}'>●</font> {escape(text)}")


def make_story(chart_paths: tuple[Path, Path]):
    story = []
    donut_path, bar_path = chart_paths

    # Capa
    story.extend([
        Spacer(1, 35 * mm),
        para("RELATÓRIO TÉCNICO  •  SEGURANÇA DE APLICAÇÃO", "CoverProjectPT"),
        HRFlowable(width="100%", thickness=3, color=hx(PALETTE["Ponto forte"]), spaceBefore=3, spaceAfter=15),
        para(REPORT_NAME, "CoverTitlePT"),
        para("Auditoria estática do cliente Flutter e do Supabase associado", "CoverProjectPT"),
        Spacer(1, 8 * mm),
    ])
    cover_data = [
        [para("DATA", "TableHeadPT"), para("ESCOPO", "TableHeadPT"), para("PROJETO SUPABASE", "TableHeadPT")],
        [plain(AUDIT_DATE, "TablePT"),
         plain("Flutter/Dart para Android e iOS; camada de dados e políticas Postgres RLS.", "TablePT"),
         plain(f"{PROJECT} ({PROJECT_REF})", "TablePT")],
    ]
    cover_table = Table(cover_data, colWidths=[1.22 * inch, 3.15 * inch, 2.25 * inch])
    cover_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), hx(PALETTE["navy"])),
        ("BACKGROUND", (0, 1), (-1, 1), hx(PALETTE["pale"])),
        ("GRID", (0, 0), (-1, -1), 0.45, hx(PALETTE["line"])),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    story.extend([cover_table, Spacer(1, 12 * mm), para("Nota metodológica", "H2PT")])
    story.append(para(
        "As cinco categorias foram adaptadas à stack detectada: isolamento foi verificado nas policies RLS do Supabase e nos filtros PostgREST; autorização no navegador foi mapeada para gates de papel no cliente versus autorização no banco (não há API própria); IDOR foi percorrido em todos os repositórios e RPCs; chaves foram buscadas em configuração, ambiente e artefatos disponíveis; XSS foi avaliado nos pontos de renderização Flutter e nos caminhos HTML/Markdown. A consulta ao banco remoto foi somente leitura.",
        "BodyPT"))
    story.append(Spacer(1, 8 * mm))
    story.append(para(
        "Resultado: 3 achados verificados. As outras categorias não tiveram falhas confirmadas nesta cobertura; não foram inventados achados para preencher uma quantidade predeterminada.",
        "CalloutPT"))
    story.append(PageBreak())

    # Resumo executivo
    story.extend([para("Resumo executivo", "H1PT")])
    sev_counts = {s: sum(1 for f in FINDINGS if f["severity"] == s)
                  for s in ("Crítica", "Alta", "Média", "Baixa")}
    summary_text = (
        f"<b>{len(FINDINGS)} achados acionáveis</b>: "
        f"{sev_counts['Crítica']} críticos, {sev_counts['Alta']} altos, "
        f"{sev_counts['Média']} médios e {sev_counts['Baixa']} baixos. "
        "O risco central é a confiança em um token estático embutido no app para autorizar policies de tabelas globais. "
        "As policies de dados pessoais, em contraste, vinculam a posse ao auth.uid()."
    )
    story.append(para(summary_text))
    metric_rows = [[para("CRÍTICA", "CenterSmallPT"), para("ALTA", "CenterSmallPT"),
                    para("MÉDIA", "CenterSmallPT"), para("BAIXA", "CenterSmallPT")],
                   [para(f"<b>{sev_counts['Crítica']}</b>", "H1PT"),
                    para(f"<b>{sev_counts['Alta']}</b>", "H1PT"),
                    para(f"<b>{sev_counts['Média']}</b>", "H1PT"),
                    para(f"<b>{sev_counts['Baixa']}</b>", "H1PT")]]
    metrics = Table(metric_rows, colWidths=[1.66 * inch] * 4, rowHeights=[0.24 * inch, 0.48 * inch])
    metrics.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), hx("#FEF2F2")),
        ("BACKGROUND", (1, 0), (1, -1), hx("#FFF7ED")),
        ("BACKGROUND", (2, 0), (2, -1), hx("#FFFBEB")),
        ("BACKGROUND", (3, 0), (3, -1), hx("#EFF6FF")),
        ("TEXTCOLOR", (0, 1), (0, 1), hx(PALETTE["Crítica"])),
        ("TEXTCOLOR", (1, 1), (1, 1), hx(PALETTE["Alta"])),
        ("TEXTCOLOR", (2, 1), (2, 1), hx(PALETTE["Média"])),
        ("TEXTCOLOR", (3, 1), (3, 1), hx(PALETTE["Baixa"])),
        ("BOX", (0, 0), (-1, -1), 0.5, hx(PALETTE["line"])),
        ("INNERGRID", (0, 0), (-1, -1), 0.35, hx(PALETTE["line"])),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    story.extend([metrics, Spacer(1, 5 * mm)])
    chart_table = Table(
        [[Image(str(donut_path), width=3.05 * inch, height=2.15 * inch),
          Image(str(bar_path), width=3.55 * inch, height=2.15 * inch)]],
        colWidths=[3.15 * inch, 3.55 * inch],
        hAlign="LEFT",
    )
    chart_table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
    ]))
    story.extend([chart_table, Spacer(1, 3 * mm)])
    story.append(para(
        "As cores seguem a severidade solicitada: crítica #B91C1C; alta #EA580C; média #D97706; baixa #2563EB; pontos fortes #059669.",
        "SmallPT"))
    story.append(PageBreak())

    # Escopo e metodologia
    story.extend([para("Stack, escopo e metodologia", "H1PT")])
    stack = [
        [para("Área", "TableHeadPT"), para("Detecção", "TableHeadPT")],
        [plain("Linguagem / frontend", "TablePT"), plain("Dart + Flutter nativo para Android/iOS; sem diretório web ou frontend JS encontrado.", "TablePT")],
        [plain("Estado / navegação", "TablePT"), plain("Riverpod e GoRouter.", "TablePT")],
        [plain("Dados / query", "TablePT"), plain("Supabase Flutter/PostgREST sobre PostgreSQL; camada GabariteiDatabase própria, sem ORM.", "TablePT")],
        [plain("Autenticação", "TablePT"), plain("Supabase Auth (GoTrue), e-mail/senha; perfil associado por auth_id e auth.uid().", "TablePT")],
        [plain("Servidor / deploy", "TablePT"), plain("Nenhum backend próprio nem Edge Function ativa; nenhum Docker, CI, Helm ou Terraform encontrado. Android Gradle e iOS Xcode são projetos de plataforma.", "TablePT")],
    ]
    stack_table = Table(stack, colWidths=[1.38 * inch, 5.28 * inch], repeatRows=1)
    stack_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), hx(PALETTE["navy"])),
        ("BACKGROUND", (0, 1), (0, -1), hx(PALETTE["pale"])),
        ("GRID", (0, 0), (-1, -1), 0.35, hx(PALETTE["line"])),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.extend([stack_table, Spacer(1, 5 * mm), para("Mapeamento das cinco categorias", "H2PT")])
    methodology = [
        "1. Banco sem tranca: Supabase RLS e predicates de ownership no catálogo remoto; filtros de usuário em todos os repositórios.",
        "2. Permissão definida no navegador: procura por gates de papel na UI e equivalente em policies. Não há backend HTTP próprio; o equivalente é RLS.",
        "3. IDOR: revisão de todos os métodos de leitura/escrita nos 13 arquivos de repositório e dos RPCs ranking_simulado e buscar_legislacao.",
        "4. Chaves expostas: arquivos de configuração, env, código, documentação e busca por padrões de credenciais. SUPABASE_ANON_KEY é publishable e foi excluída como segredo.",
        "5. XSS: procura de sinks HTML/JS, renderizadores Markdown, URLs e templates. Flutter exibe os conteúdos em Text/TextSpan; não há DOM/WebView no app.",
    ]
    for item in methodology:
        story.append(para(escape(item)))
    story.append(Spacer(1, 2 * mm))
    story.append(para(
        "O estado remoto foi consultado em modo somente leitura: 36 tabelas do schema public estão com RLS habilitado. As policies de admins e logs_admin não existem, mas o acesso SELECT/INSERT/UPDATE/DELETE para anon e authenticated está negado; o comportamento é fail-closed. Não há arquivo local de migrations SQL, portanto evidências RLS são identificadas por schema/tabela/policy, sem fabricar número de linha.",
        "CalloutPT"))
    story.append(PageBreak())

    # Pontos fortes e fracos
    story.extend([para("Pontos fortes e pontos fracos", "H1PT"), para("Pontos fortes verificados", "H2PT")])
    strongs = [
        ("Posse vinculada à identidade", "public.eh_dono_do_aluno(int/text) exige auth.uid() não nulo e associação usuarios.auth_id = auth.uid(); aplicado às tabelas pessoais."),
        ("Filtros de proprietário no cliente", "caderno_repository.dart:19–21, 58–61, 77–81; flashcard_repository.dart:168–198; dashboard_repository.dart:29–50 filtram pelo usuário. RLS é a autoridade final, não o filtro do cliente."),
        ("Perfil ligado à sessão", "auth_repository.dart:128–136 busca usuarios pelo auth_id do AuthUser atual; a policy remota de usuarios também verifica auth.uid()."),
        ("Privados e RPC", "simulado_repository.dart:264–279 verifica criador; ranking_simulado remoto exige auth.uid() e limita acesso ao dono quando o simulado é privado."),
        ("Conteúdo público separado", "tabelas de taxonomia têm policies SELECT públicas; questões ficam limitadas a status=publicada. Views públicas consultadas usam security_invoker=true."),
        ("Admin fechado", "admins e logs_admin têm RLS ativo, zero policies e nenhum privilégio para anon/authenticated; o aviso INFO do advisor é um deny-all esperado."),
        ("Renderização sem HTML executável", "flashcards_ui.dart:236–305 gera TextSpan de tags limitadas; resumo_content_formatter.dart converte para blocos/texto. Não há innerHTML, WebView, eval ou renderer HTML."),
        ("Chaves BYOK locais", "ia_config_store.dart:6–28 usa flutter_secure_storage; chave de IA é mantida no Keychain/Keystore, não no Supabase."),
    ]
    for title, detail in strongs:
        story.append(bullet(detail, title + ":"))
    story.extend([Spacer(1, 3 * mm), para("Pontos fracos centrais", "H2PT")])
    weaknesses = [
        "F-01: policies de caches e feedbacks confiam apenas em eh_app_aluno(), que não identifica um usuário; existe risco cross-user em dados globais.",
        "F-02: APP_TOKEN é compilado no app e pode ser extraído; env.json estar no .gitignore não impede extração do APK/IPA.",
        "F-03: opencode.json contém X-Goog-Api-Key literal; exploração depende de validade/restrições.",
        "Cobertura limitada: não existe .git; histórico não pôde ser inspecionado. O checkout não disponibiliza APK/AAB ou bundle web para análise binária; build/ está ignorado. A inclusão do token no app é comprovada estaticamente pelo dart-define e cabeçalho enviado.",
    ]
    for text in weaknesses:
        story.append(para(f"<font color='{PALETTE['Alta']}'>●</font> {escape(text)}"))
    story.append(Spacer(1, 2 * mm))
    story.append(para(
        "Verificação de defaults: env.example.json contém placeholders não vazios e AppConfig.isConfigured valida apenas presença. Um build com o exemplo não passa o valor esperado por eh_app_aluno() e falha fechado (perda de funcionalidade), portanto isso não foi contado como bypass de segurança.",
        "SmallPT"))
    story.append(PageBreak())

    # Achados por categoria
    story.extend([para("Achados detalhados por categoria", "H1PT")])
    for index, category in enumerate(CATEGORIES):
        story.append(para(category, "H2PT"))
        story.append(finding_table(category))
        if index < len(CATEGORIES) - 1:
            story.append(Spacer(1, 3 * mm))
    story.append(Spacer(1, 4 * mm))
    story.append(para(
        "Observação de evidência: as policies são configuração remota do projeto Supabase, não arquivos versionados no checkout. As referências de arquivo/linha acima apontam o fluxo cliente correspondente; a policy remota é nomeada integralmente para permitir conferência no projeto.",
        "SmallPT"))
    story.append(PageBreak())

    # Recomendações
    story.extend([para("Recomendações priorizadas", "H1PT")])
    recommendations = [
        ("P1", "Eliminar a falsa fronteira do APP_TOKEN", "Remover o segredo compartilhado do Flutter e das policies. Separar leitura pública de gravação global; usar Edge Function com JWT, autorização, validação e rate limit para gravar cache/feedback."),
        ("P1", "Restringir feedbacks e caches no banco", "SELECT de feedbacks apenas para administração; escrita do cache apenas por processo confiável. Aplicar auth.uid()/ownership onde houver dados pessoais e constraint única (id_questao, tipo) em ia_cache_estudo."),
        ("P2", "Rotacionar/restringir a chave Google", "Se ativa, revogar e criar uma chave restrita ao serviço/quota necessária; guardar fora da configuração compartilhada do projeto."),
        ("P2", "Testes automatizados de RLS", "Executar casos anon, usuário A e usuário B para cada tabela pessoal e global, incluindo listagem, busca, contagem, insert, update, delete, RPC e views."),
        ("P3", "Versionar a infraestrutura de segurança", "Adicionar migrations e testes de policies ao repositório. Quando o histórico Git estiver disponível, procurar credenciais antigas e revogá-las; verificar o APK/AAB de release com ferramenta de inspeção binária."),
    ]
    for priority, title, text in recommendations:
        cell = Table([[para(priority, "ChipPT"), para(f"<b>{escape(title)}</b><br/>{escape(text)}", "BodyPT")]],
                     colWidths=[0.62 * inch, 6.0 * inch])
        color = PALETTE["Alta"] if priority == "P1" else PALETTE["Média"] if priority == "P2" else PALETTE["Baixa"]
        cell.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), hx(color)),
            ("BACKGROUND", (1, 0), (1, 0), hx(PALETTE["pale"])),
            ("BOX", (0, 0), (-1, -1), 0.45, hx(PALETTE["line"])),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 7),
            ("RIGHTPADDING", (0, 0), (-1, -1), 7),
            ("TOPPADDING", (0, 0), (-1, -1), 6),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ]))
        story.extend([cell, Spacer(1, 3 * mm)])
    story.append(para(
        "A auditoria foi somente leitura; nenhuma policy, dado, chave ou configuração remota foi alterada.",
        "SmallPT"))
    story.append(PageBreak())

    # Issues, sempre no final
    story.extend([para("ISSUES PARA O GITHUB", "H1PT"),
                  para("Os blocos abaixo são issues completas em Markdown. Segredos foram redigidos; copie o bloco e substitua evidências sensíveis apenas em canal privado.", "BodyPT")])
    for issue in (ISSUE_1, ISSUE_2):
        story.append(Preformatted(issue, STYLES["MonoPT"], maxLineLength=84,
                                  splitChars=" ,./:-_()[]"))
        story.append(Spacer(1, 5 * mm))

    return story


def build_pdf():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    left = right = 20 * mm
    top = 20 * mm
    bottom = 20 * mm
    doc = BaseDocTemplate(
        str(OUTPUT), pagesize=A4,
        leftMargin=left, rightMargin=right,
        topMargin=top, bottomMargin=bottom,
        title=REPORT_NAME,
        author="Auditoria de Segurança — gabaritei_app",
        subject="Auditoria Flutter/Dart e Supabase RLS",
    )
    frame = Frame(left, bottom, A4[0] - left - right, A4[1] - top - bottom,
                  id="content", leftPadding=0, rightPadding=0,
                  topPadding=0, bottomPadding=0)
    doc.addPageTemplates([PageTemplate(id="report", frames=[frame], onPage=draw_page_chrome)])
    with tempfile.TemporaryDirectory(prefix="gabaritei-security-charts-") as temp:
        donut = Path(temp) / "severidade.png"
        bars = Path(temp) / "categorias.png"
        chart_severity(donut)
        chart_categories(bars)
        doc.build(make_story((donut, bars)))


def verify_pdf(preview_dir: Path | None = None) -> int:
    if not OUTPUT.exists() or OUTPUT.stat().st_size < 10_000:
        raise RuntimeError("PDF ausente ou inesperadamente pequeno.")
    pdf = pymupdf.open(OUTPUT)
    page_count = pdf.page_count
    if page_count < 5:
        raise RuntimeError(f"Número de páginas inesperado: {pdf.page_count}.")
    extracted = "\n".join(page.get_text() for page in pdf)
    required = ["Resumo executivo", "Pontos fortes", "Achados detalhados", "ISSUES PARA O GITHUB",
                "--- ISSUE 1 ---", "--- FIM ISSUE 2 ---"]
    missing = [term for term in required if term.casefold() not in extracted.casefold()]
    if missing:
        raise RuntimeError("Texto ausente no PDF: " + ", ".join(missing))
    if preview_dir is not None:
        preview_dir.mkdir(parents=True, exist_ok=True)
        target = preview_dir
        cleanup = None
    else:
        cleanup = tempfile.TemporaryDirectory(prefix="gabaritei-security-pages-")
        target = Path(cleanup.name)
    try:
        for number, page in enumerate(pdf, start=1):
            pix = page.get_pixmap(matrix=pymupdf.Matrix(1.05, 1.05), alpha=False)
            pix.save(target / f"pagina-{number:02d}.png")
        image_pages = [page for page in pdf if page.get_images(full=True)]
        if not image_pages:
            raise RuntimeError("Nenhum gráfico/imagem embutido foi encontrado no PDF.")
        print(f"PDF validado: {pdf.page_count} páginas; {len(image_pages)} página(s) com imagens/gráficos.")
        if preview_dir is not None:
            print(f"Rasterizações para revisão visual: {preview_dir}")
    finally:
        if cleanup is not None:
            cleanup.cleanup()
        pdf.close()
    return page_count


def main():
    parser = argparse.ArgumentParser(description="Gera e valida o relatório de auditoria em PDF.")
    parser.add_argument("--preview-dir", type=Path, default=None,
                        help="Diretório opcional para rasterizar as páginas e revisar o layout.")
    args = parser.parse_args()
    build_pdf()
    verify_pdf(args.preview_dir)
    print(f"Relatório gerado: {OUTPUT}")


if __name__ == "__main__":
    main()
