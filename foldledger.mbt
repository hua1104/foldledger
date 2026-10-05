///|
/// Reading direction of the bound booklet.
pub(all) enum Binding {
  Left
  Right
} derive(Eq)

///|
/// Landscape duplex edge. Long-edge backs need a 180-degree content rotation.
pub(all) enum Duplex {
  ShortEdge
  LongEdge
} derive(Eq)

///|
/// Each signature is a separately folded and nested gathering.
pub(all) struct Config {
  signature_pages : Int
  binding : Binding
  duplex : Duplex
}

///|
/// Page 0 means an inserted blank. All other values are original document pages.
pub(all) struct Sheet {
  signature : Int
  depth : Int
  front_left : Int
  front_right : Int
  back_left : Int
  back_right : Int
  back_rotation : Int
}

///|
/// Array order is signature order, then outermost to innermost sheet.
pub(all) struct Plan {
  source_pages : Int
  selected : Array[Int]
  padded_pages : Int
  blanks : Int
  signatures : Int
  config : Config
  sheets : Array[Sheet]
}

///|
pub fn default_config() -> Config {
  {
    // Four sheets per separately folded gathering.
    signature_pages: 16,
    // Faces are viewed from their own printed side.
    binding: Left,
    // Landscape short-edge duplex requires no back rotation.
    duplex: ShortEdge,
  }
}

///|
/// Strict bounded integer parser used by the selection grammar and CLI.
pub fn parse_positive(text : String, maximum : Int) -> Result[Int, String] {
  if text == "" || maximum < 1 {
    return Err("expected a positive integer")
  }
  let mut value = 0
  for ch in text {
    if ch < '0' || ch > '9' {
      return Err("expected decimal digits only")
    }
    let digit = ch.to_int() - '0'.to_int()
    if digit > maximum || value > (maximum - digit) / 10 {
      return Err("number exceeds supported limit")
    }
    value = value * 10 + digit
  }
  if value == 0 {
    Err("zero is not allowed")
  } else {
    Ok(value)
  }
}

///| A comma-separated list of pages and inclusive ascending ranges.

///|
/// Order is preserved. Duplicate, descending and out-of-document pages are errors.
pub fn parse_selection(
  text : String,
  total : Int,
) -> Result[Array[Int], String] {
  if total < 1 || total > 10000 {
    return Err("document page count must be 1..10000")
  }
  if text.trim().to_owned() == "" {
    return Err("selection must not be empty")
  }
  let pages : Array[Int] = []
  let seen = Array::make(total + 1, false)
  for part in text.split(",") {
    let range = part.trim().to_owned().split("-").to_array()
    if range.length() < 1 || range.length() > 2 {
      return Err("invalid page range")
    }
    let first = match parse_positive(range[0].trim().to_owned(), total) {
      Ok(n) => n
      Err(e) => return Err(e)
    }
    let last = if range.length() == 2 {
      match parse_positive(range[1].trim().to_owned(), total) {
        Ok(n) => n
        Err(e) => return Err(e)
      }
    } else {
      first
    }
    if last < first {
      return Err("descending ranges are not supported")
    }
    for p = first; p <= last; p = p + 1 {
      if seen[p] {
        return Err("selection repeats page " + p.to_string())
      }
      seen[p] = true
      pages.push(p)
    }
  }
  Ok(pages)
}

///| Validate first, then construct a deterministic booklet plan without I/O.

///|
/// Last signature is padded only to the nearest multiple of four.
pub fn make_plan(
  total : Int,
  selected : Array[Int],
  config : Config,
) -> Result[Plan, String] {
  if total < 1 || total > 10000 {
    return Err("document page count must be 1..10000")
  }
  if config.signature_pages < 4 ||
    config.signature_pages > 64 ||
    config.signature_pages % 4 != 0 {
    return Err("signature size must be a multiple of 4 in 4..64")
  }
  if selected.length() == 0 {
    return Err("selection must not be empty")
  }
  let seen = Array::make(total + 1, false)
  for page in selected {
    if page < 1 || page > total {
      return Err("selected page is outside the document")
    }
    if seen[page] {
      return Err("selection repeats page " + page.to_string())
    }
    seen[page] = true
  }
  let sheets : Array[Sheet] = []
  let mut offset = 0
  let mut signatures = 0
  let mut padded_pages = 0
  while offset < selected.length() {
    signatures = signatures + 1
    let remaining = selected.length() - offset
    let count = if remaining < config.signature_pages {
      remaining
    } else {
      config.signature_pages
    }
    let padded = (count + 3) / 4 * 4
    padded_pages = padded_pages + padded
    for depth = 0; depth < padded / 4; depth = depth + 1 {
      let fl = slot(selected, offset, count, padded - 1 - depth * 2)
      let fr = slot(selected, offset, count, depth * 2)
      let bl = slot(selected, offset, count, depth * 2 + 1)
      let br = slot(selected, offset, count, padded - 2 - depth * 2)
      let right = config.binding == Right
      sheets.push({
        signature: signatures,
        depth: depth + 1,
        front_left: if right {
          fr
        } else {
          fl
        },
        front_right: if right {
          fl
        } else {
          fr
        },
        back_left: if right {
          br
        } else {
          bl
        },
        back_right: if right {
          bl
        } else {
          br
        },
        back_rotation: if config.duplex == LongEdge {
          180
        } else {
          0
        },
      })
    }
    offset = offset + count
  }
  Ok({
    source_pages: total,
    selected: selected.copy(),
    padded_pages,
    blanks: padded_pages - selected.length(),
    signatures,
    config,
    sheets,
  })
}

///|
fn slot(pages : Array[Int], offset : Int, count : Int, index : Int) -> Int {
  if index >= count {
    0
  } else {
    pages[offset + index]
  }
}

///|
pub fn plan_to_json(plan : Plan) -> String {
  let rows : Array[String] = []
  for sheet in plan.sheets {
    rows.push(
      "{\"signature\":" +
      sheet.signature.to_string() +
      ",\"depth\":" +
      sheet.depth.to_string() +
      ",\"front\":[" +
      sheet.front_left.to_string() +
      "," +
      sheet.front_right.to_string() +
      "],\"back\":[" +
      sheet.back_left.to_string() +
      "," +
      sheet.back_right.to_string() +
      "],\"back_rotation\":" +
      sheet.back_rotation.to_string() +
      "}",
    )
  }
  "{\"schema_version\":1,\"blank_page\":0,\"source_pages\":" +
  plan.source_pages.to_string() +
  ",\"selected\":[" +
  plan.selected.map(fn(n) { n.to_string() }).join(",") +
  "],\"signature_pages\":" +
  plan.config.signature_pages.to_string() +
  ",\"binding\":\"" +
  (if plan.config.binding == Left { "left" } else { "right" }) +
  "\",\"duplex\":\"" +
  (if plan.config.duplex == ShortEdge { "short" } else { "long" }) +
  "\",\"padded_pages\":" +
  plan.padded_pages.to_string() +
  ",\"blanks\":" +
  plan.blanks.to_string() +
  ",\"signatures\":" +
  plan.signatures.to_string() +
  ",\"sheets\":[" +
  rows.join(",") +
  "]}\n"
}

///|
fn page_label(page : Int) -> String {
  if page == 0 {
    "BLANK"
  } else {
    page.to_string()
  }
}

///|
pub fn plan_to_text(plan : Plan) -> String {
  let lines = [
    "FoldLedger | " +
    plan.selected.length().to_string() +
    " selected pages | " +
    plan.sheets.length().to_string() +
    " sheets | " +
    plan.blanks.to_string() +
    " blanks",
    "Signature / sheet : FRONT left | right ; BACK left | right ; back rotation",
  ]
  for sheet in plan.sheets {
    lines.push(
      sheet.signature.to_string() +
      " / " +
      sheet.depth.to_string() +
      " : " +
      page_label(sheet.front_left) +
      " | " +
      page_label(sheet.front_right) +
      " ; " +
      page_label(sheet.back_left) +
      " | " +
      page_label(sheet.back_right) +
      " ; " +
      sheet.back_rotation.to_string(),
    )
  }
  lines.join("\n") + "\n"
}

///| Accessible diagram of at most 24 sheets; JSON always includes the full plan.

///|
/// Faces are viewed separately from their own printed side before duplex rotation.
pub fn plan_to_svg(plan : Plan) -> String {
  let shown = if plan.sheets.length() > 24 { 24 } else { plan.sheets.length() }
  let height = 172 + shown * 154
  let parts = [
    "<svg xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-labelledby=\"title desc\" width=\"1000\" height=\"" +
    height.to_string() +
    "\" viewBox=\"0 0 1000 " +
    height.to_string() +
    "\"><title id=\"title\">FoldLedger booklet imposition</title><desc id=\"desc\">Each row is one sheet, outermost first. Each face is viewed from its printed side. Dashed lines indicate folds. Blank slots are intentionally empty.</desc><rect width=\"100%\" height=\"100%\" fill=\"#f3f5f7\"/><g font-family=\"Arial, sans-serif\" fill=\"#172b4d\"><text x=\"36\" y=\"44\" font-size=\"28\" font-weight=\"bold\">FoldLedger / booklet plan</text><text x=\"36\" y=\"77\" font-size=\"16\">" +
    plan.selected.length().to_string() +
    " selected pages / " +
    plan.sheets.length().to_string() +
    " sheets / " +
    plan.signatures.to_string() +
    " signatures / " +
    plan.blanks.to_string() +
    " blanks</text><text x=\"36\" y=\"106\" font-size=\"13\">" +
    (if plan.config.binding == Left { "Left binding" } else { "Right binding" }) +
    " / " +
    (if plan.config.duplex == ShortEdge {
      "short-edge duplex"
    } else {
      "long-edge duplex: rotate each back face 180 degrees"
    }) +
    " / preview " +
    shown.to_string() +
    " of " +
    plan.sheets.length().to_string() +
    " sheets</text>",
  ]
  for i = 0; i < shown; i = i + 1 {
    let sheet = plan.sheets[i]
    let y = 132 + i * 154
    parts.push(
      "<text x=\"36\" y=\"" +
      (y + 17).to_string() +
      "\" font-size=\"13\">Signature " +
      sheet.signature.to_string() +
      " / sheet " +
      sheet.depth.to_string() +
      " (outer to inner)</text>",
    )
    parts.push(
      face_svg(36, y + 30, sheet.front_left, sheet.front_right, "FRONT", 0),
    )
    parts.push(
      face_svg(
        516,
        y + 30,
        sheet.back_left,
        sheet.back_right,
        "BACK",
        sheet.back_rotation,
      ),
    )
  }
  parts.push("</g></svg>\n")
  parts.join("")
}

///|
fn face_svg(
  x : Int,
  y : Int,
  left : Int,
  right : Int,
  label : String,
  rotation : Int,
) -> String {
  let center = x + 220
  "<g><rect x=\"" +
  x.to_string() +
  "\" y=\"" +
  y.to_string() +
  "\" width=\"440\" height=\"104\" rx=\"8\" fill=\"white\" stroke=\"#c0cad6\"/><text x=\"" +
  (x + 12).to_string() +
  "\" y=\"" +
  (y + 20).to_string() +
  "\" font-size=\"11\" fill=\"#61728b\">" +
  label +
  " / rotate " +
  rotation.to_string() +
  "</text><path d=\"M " +
  center.to_string() +
  " " +
  y.to_string() +
  " v 104\" stroke=\"#9aaec2\" stroke-dasharray=\"5 5\"/><g transform=\"rotate(" +
  rotation.to_string() +
  " " +
  center.to_string() +
  " " +
  (y + 52).to_string() +
  ")\" text-anchor=\"middle\" font-size=\"27\" font-weight=\"bold\"><text x=\"" +
  (x + 110).to_string() +
  "\" y=\"" +
  (y + 67).to_string() +
  "\">" +
  page_label(left) +
  "</text><text x=\"" +
  (x + 330).to_string() +
  "\" y=\"" +
  (y + 67).to_string() +
  "\">" +
  page_label(right) +
  "</text></g></g>"
}
