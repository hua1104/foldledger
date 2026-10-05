///|
fn require_plan(
  total : Int,
  selected : Array[Int],
  config : @foldledger.Config,
) -> @foldledger.Plan {
  match @foldledger.make_plan(total, selected, config) {
    Ok(plan) => plan
    Err(message) => abort(message)
  }
}

///|
test "8-page booklet reference layout and 20-page signature boundary" {
  let plan = require_plan(
    8,
    [1, 2, 3, 4, 5, 6, 7, 8],
    @foldledger.default_config(),
  )
  let outer = plan.sheets[0]
  assert_eq(outer.front_left, 8)
  assert_eq(outer.front_right, 1)
  assert_eq(outer.back_left, 2)
  assert_eq(outer.back_right, 7)
  let inner = plan.sheets[1]
  assert_eq(inner.front_left, 6)
  assert_eq(inner.front_right, 3)
  assert_eq(inner.back_left, 4)
  assert_eq(inner.back_right, 5)
  let multi = require_plan(
    20,
    Array::makei(20, fn(i) { i + 1 }),
    @foldledger.default_config(),
  )
  assert_eq(multi.signatures, 2)
  assert_eq(multi.sheets.length(), 5)
  assert_eq(multi.sheets[4].front_left, 20)
  assert_eq(multi.sheets[4].front_right, 17)
  assert_eq(multi.blanks, 0)
}

///|
test "range order and blank padding retain original page numbers" {
  let selected = match @foldledger.parse_selection(" 9-10, 2, 5-6 ", 10) {
    Ok(p) => p
    Err(e) => abort(e)
  }
  let plan = require_plan(10, selected, @foldledger.default_config())
  assert_eq(plan.selected, [9, 10, 2, 5, 6])
  assert_eq(plan.blanks, 3)
  assert_eq(plan.sheets[0].front_left, 0)
  assert_eq(plan.sheets[0].front_right, 9)
  assert_eq(plan.sheets[0].back_left, 10)
  assert_eq(plan.sheets[1].back_left, 5)
  assert_eq(plan.sheets[1].back_right, 6)
}

///|
test "right binding mirrors faces and long-edge duplex rotates only backs" {
  let plan = require_plan(4, [1, 2, 3, 4], {
    signature_pages: 4,
    binding: Right,
    duplex: LongEdge,
  })
  let s = plan.sheets[0]
  assert_eq([s.front_left, s.front_right, s.back_left, s.back_right], [
    1, 4, 3, 2,
  ])
  assert_eq(s.back_rotation, 180)
  assert_true(@foldledger.plan_to_svg(plan).contains("rotate(180"))
}

///|
test "invalid selections and overflow are rejected without panics" {
  for
    input in [
      "", "0", "1,1", "3-1", "11", "1,,2", "-1", "1-2-3", "9999999999999999999999",
      "1.5", "1-",
    ] {
    assert_true(@foldledger.parse_selection(input, 10) is Err(_))
  }
  assert_true(
    @foldledger.parse_positive("9999999999999999999", 10000) is Err(_),
  )
  assert_true(
    @foldledger.make_plan(0, [1], @foldledger.default_config()) is Err(_),
  )
  assert_true(
    @foldledger.make_plan(2, [], @foldledger.default_config()) is Err(_),
  )
  assert_true(
    @foldledger.make_plan(2, [1, 1], @foldledger.default_config()) is Err(_),
  )
  assert_true(
    @foldledger.make_plan(2, [3], @foldledger.default_config()) is Err(_),
  )
  for size in [0, 3, 6, 65] {
    assert_true(
      @foldledger.make_plan(2, [1, 2], {
        signature_pages: size,
        binding: Left,
        duplex: ShortEdge,
      })
      is Err(_),
    )
  }
}

///|
/// Independent conservation and fold-pair invariants across 2580 combinations.
test "exhaustive page conservation and fold pairs across bindings and duplex edges" {
  for count = 1; count <= 129; count = count + 1 {
    for size in [4, 8, 16, 32, 64] {
      for binding in [@foldledger.Binding::Left, @foldledger.Binding::Right] {
        for
          duplex in [
            @foldledger.Duplex::ShortEdge,
            @foldledger.Duplex::LongEdge,
          ] {
          let plan = require_plan(count, Array::makei(count, fn(i) { i + 1 }), {
            signature_pages: size,
            binding,
            duplex,
          })
          let seen = Array::make(count + 1, 0)
          let mut blanks = 0
          for s in plan.sheets {
            for p in [s.front_left, s.front_right, s.back_left, s.back_right] {
              if p == 0 {
                blanks = blanks + 1
              } else {
                seen[p] = seen[p] + 1
              }
            }
            let base = (s.signature - 1) * size
            let remaining = count - base
            let in_signature = if remaining < size { remaining } else { size }
            let padded = (in_signature + 3) / 4 * 4
            if s.front_left > 0 && s.front_right > 0 {
              assert_eq(s.front_left + s.front_right, 2 * base + padded + 1)
            }
            if s.back_left > 0 && s.back_right > 0 {
              assert_eq(s.back_left + s.back_right, 2 * base + padded + 1)
            }
          }
          for p = 1; p <= count; p = p + 1 {
            assert_eq(seen[p], 1)
          }
          assert_eq(blanks, plan.blanks)
          assert_eq(plan.sheets.length() * 4, count + blanks)
          assert_eq(plan.signatures, (count + size - 1) / size)
        }
      }
    }
  }
}

///|
test "SVG preview is accessible and bounded while JSON includes all sheets" {
  let plan = require_plan(
    10000,
    Array::makei(10000, fn(i) { i + 1 }),
    @foldledger.default_config(),
  )
  let svg = @foldledger.plan_to_svg(plan)
  assert_eq(plan.sheets.length(), 2500)
  assert_true(svg.contains("preview 24 of 2500 sheets"))
  assert_true(svg.contains("aria-labelledby"))
  assert_true(svg.length() < 50000)
  assert_true(@foldledger.plan_to_json(plan).contains("\"signature\":625"))
}

///|
test "plan owns selected pages and output is deterministic" {
  let pages = [1, 2, 3]
  let plan = require_plan(3, pages, @foldledger.default_config())
  let before = @foldledger.plan_to_json(plan)
  pages[0] = 3
  assert_eq(plan.selected[0], 1)
  assert_eq(@foldledger.plan_to_json(plan), before)
  assert_true(@foldledger.plan_to_text(plan).contains("BLANK"))
}
