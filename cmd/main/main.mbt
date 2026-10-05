///|
fn fail(message : String) -> Unit {
  error_line("foldledger: " + message)
  exit_with(2)
}

///|
fn main {
  let args = Array::from_fixed_array(cli_args())
  let mut total = 0
  let mut signature = 16
  let mut selection : String? = None
  let mut binding = @lib.Left
  let mut duplex = @lib.ShortEdge
  let mut json_path = ""
  let mut svg_path = ""
  let mut json_stdout = false
  let seen : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" || arg == "-h" {
      help()
      exit_with(0)
    }
    if arg == "--version" {
      println("foldledger 0.1.0")
      exit_with(0)
    }
    if seen.contains(arg) {
      fail("duplicate option: " + arg)
    }
    seen.push(arg)
    if arg == "--json" {
      json_stdout = true
      i = i + 1
      continue
    }
    if ![
        "--pages", "--select", "--signature", "--binding", "--duplex", "--out", "--svg",
      ].contains(arg) {
      fail("unknown option: " + arg)
    }
    if i + 1 >= args.length() || args[i + 1].has_prefix("--") {
      fail("missing value for " + arg)
    }
    let value = args[i + 1]
    if value == "" {
      fail("empty value for " + arg)
    }
    match arg {
      "--pages" =>
        total = match @lib.parse_positive(value, 10000) {
          Ok(n) => n
          Err(e) => {
            fail(e)
            0
          }
        }
      "--signature" =>
        signature = match @lib.parse_positive(value, 64) {
          Ok(n) => n
          Err(e) => {
            fail(e)
            0
          }
        }
      "--select" => selection = Some(value)
      "--binding" =>
        if value == "left" {
          binding = @lib.Left
        } else if value == "right" {
          binding = @lib.Right
        } else {
          fail("binding must be left or right")
        }
      "--duplex" =>
        if value == "short" {
          duplex = @lib.ShortEdge
        } else if value == "long" {
          duplex = @lib.LongEdge
        } else {
          fail("duplex must be short or long")
        }
      "--out" => json_path = value
      "--svg" => svg_path = value
      _ => ()
    }
    i = i + 2
  }
  if total == 0 {
    fail("--pages is required (1..10000)")
  }
  let selected = match selection {
    Some(s) =>
      match @lib.parse_selection(s, total) {
        Ok(pages) => pages
        Err(e) => {
          fail(e)
          []
        }
      }
    None => Array::makei(total, fn(i) { i + 1 })
  }
  match
    @lib.make_plan(total, selected, {
      signature_pages: signature,
      binding,
      duplex,
    }) {
    Err(e) => fail(e)
    Ok(plan) => {
      // All validation and serialization complete before the host writes anything.
      let json = @lib.plan_to_json(plan)
      let svg = if svg_path != "" { @lib.plan_to_svg(plan) } else { "" }
      let error = save_outputs(json_path, json, svg_path, svg)
      if error != "" {
        fail(error)
      }
      if json_stdout {
        println(json)
      } else {
        println(@lib.plan_to_text(plan))
      }
    }
  }
}

///|
fn help() -> Unit {
  println("FoldLedger 0.1.0 | booklet imposition planner")
  println(
    "moon run cmd/main -- --pages 20 --signature 16 --out plan.json --svg preview.svg",
  )
  println(
    "--select 1-8,13-20   select original pages, preserving order; duplicates rejected",
  )
  println(
    "--signature 16      pages per folded gathering, multiple of 4 in 4..64",
  )
  println("--binding left      left or right")
  println(
    "--duplex short      landscape short or long edge; long backs rotate 180 degrees",
  )
  println("--json              print only JSON on stdout")
  println(
    "--out PATH --svg PATH   optional outputs; existing files are never overwritten",
  )
  println(
    "Page 0 is blank. Output is a plan, not a transformed PDF. Exit 0 success; 2 error.",
  )
}

///|
extern "js" fn cli_args() -> FixedArray[String] =
  #| () => process.argv.slice(2)

///|
extern "js" fn exit_with(code : Int) -> Unit =
  #| code => process.exit(code)

///|
extern "js" fn error_line(text : String) -> Unit =
  #| text => process.stderr.write(text + "\n")

///|
/// Host adapter only: path validation and exclusive file creation, no imposition logic.
extern "js" fn save_outputs(
  json_path : String,
  json : String,
  svg_path : String,
  svg : String,
) -> String =
  #| (jsonPath, json, svgPath, svg) => {
  #|   const fs = require('fs'), path = require('path');
  #|   const outputs = [[jsonPath,json],[svgPath,svg]].filter(([p]) => p !== '').map(([p,s]) => [path.resolve(p),s]);
  #|   const key = p => process.platform === 'win32' ? p.toLowerCase() : p;
  #|   const created = [];
  #|   try {
  #|     if (new Set(outputs.map(([p]) => key(p))).size !== outputs.length) return 'output paths must be different';
  #|     for (const [p] of outputs) {
  #|       if (fs.existsSync(p)) return 'output already exists: ' + p;
  #|       if (!fs.statSync(path.dirname(p)).isDirectory()) return 'output parent must be a directory';
  #|     }
  #|     for (const [p,s] of outputs) {
  #|       const fd = fs.openSync(p,'wx'); created.push(p);
  #|       try { fs.writeFileSync(fd,s,'utf8'); } finally { fs.closeSync(fd); }
  #|     }
  #|     return '';
  #|   } catch (e) {
  #|     for (const p of created) { try { fs.unlinkSync(p); } catch (_) {} }
  #|     return 'cannot write output (' + (e.code || 'IO_ERROR') + ')';
  #|   }
  #| }
