require './test_common'

class WinMove
  include Bud

  state do
    poset :move, [:from, :to]
    table :win, [:pos]
  end

  stratum 0 do
    win <= move.notin(win, :to => :pos).pro {|m| [m.from]}
  end
end

class TestWinMove < MiniTest::Unit::TestCase
  def test_win_move_1
    w = WinMove.new
    w.move <+ [["A", "B"],
               ["B", "C"]]
    w.tick

    assert_equal([["B"]].to_set, w.win.to_set)
  end

  # Two disconnected graphs
  def test_win_move_2
    w = WinMove.new
    w.move <+ [["A", "B"],
               ["B", "C"],
               ["X", "Y"],
               ["Y", "Z"]]
    w.tick

    assert_equal([["B"], ["Y"]].to_set, w.win.to_set)
  end

  # Positions reachable from multiple squares (B -> A, C -> A, D -> A).
  def test_win_move_3
    w = WinMove.new
    w.move <+ [["B", "A"],
               ["C", "A"],
               ["D", "A"],
               ["E", "B"],
               ["F", "E"],
               ["G", "F"],
               ["H", "G"]]
    w.tick

    assert_equal([["B"], ["F"], ["H"], ["C"], ["D"]].to_set, w.win.to_set)
  end

  # Moves that are transitively redundant (B -> A, C -> B, C -> A)
  def test_win_move_4
    w = WinMove.new
    w.move <+ [["B", "A"],
               ["C", "B"],
               ["C", "A"]]
    w.tick

    assert_equal([["B"], ["C"]].to_set, w.win.to_set)
  end
end

class PartHierarchy
  include Bud

  state do
    poset :part, [:id, :child]
    table :tested, [:id]
    scratch :working, [:id]
    scratch :has_suspect_part, [:id]
  end

  stratum 0 do
    working <= tested
  end

  stratum 1 do
    has_suspect_part <= part.notin(working, :child => :id).pro {|p| [p.id]}
  end

  stratum 2 do
    working <= part {|p| [p.id]}.notin(has_suspect_part)
  end
end

class TestPartHierarchy < MiniTest::Unit::TestCase
  def test_part_hierarchy1
    p = PartHierarchy.new
    p.part <+ [["house", "kitchen"],
               ["house", "garage"],
               ["house", "bedroom"]]
    p.tick

    assert_equal([].to_set, p.working.to_set)
    assert_equal([["house"]].to_set, p.has_suspect_part.to_set)
  end

  def test_part_hierarchy2
    p = PartHierarchy.new
    p.part <+ [["house", "kitchen"],
               ["house", "garage"],
               ["house", "bedroom"]]
    p.tested <+ [["kitchen"], ["garage"], ["bedroom"]]
    p.tick

    assert_equal([["house"], ["kitchen"],
                  ["garage"], ["bedroom"]].to_set, p.working.to_set)
    assert_equal([].to_set, p.has_suspect_part.to_set)
  end

  def test_part_hierarchy3
    p = PartHierarchy.new
    p.part <+ [["A", "B"],
               ["B", "C"],
               ["C", "D"],
               ["A", "E"],
               ["X", "E"]]
    p.tested <+ [["D"]]
    p.tick

    assert_equal([["D"], ["C"], ["B"]].to_set, p.working.to_set)
    assert_equal([["A"], ["X"]].to_set, p.has_suspect_part.to_set)
  end
end

class PosetSimple
  include Bud

  state do
    poset :t1, [:x, :y]
    table :t2, t1.schema
  end

  bloom do
    t2 <= t1 {|t| [t.x + 1, t.y + 2]}
  end
end

class PosetKeys
  include Bud

  state do
    poset :t1, [:x] => [:y]
    table :t2, [:x, :y]
  end

  bloom do
    t1 <= t2 {|t| [t.x + 10, t.y + 12]}
  end
end

class PosetDelta
  include Bud

  state do
    table :t1
    poset :t2, [:x, :y]
    table :t3
  end

  bloom do
    t2 <= t1
    t3 <= t2
  end
end

class TestPoset < MiniTest::Unit::TestCase
  def test_poset_simple
    t = PosetSimple.new
    t.t1 <+ [[5, 1], [5, 2], [10, 5]]
    t.tick

    assert_equal([[6, 3], [6, 4], [11, 7]].to_set, t.t2.to_set)
  end

  def test_poset_keys1
    t = PosetKeys.new
    assert_raises(Bud::KeyConstraintError) { t.t1 <+ [[5, 10], [5, 11]] }
  end

  def test_poset_keys2
    t = PosetKeys.new
    t.t1 <+ [[15, 14]]
    t.tick

    # Allow duplicates
    t.t2 <+ [[5, 2]]
    t.tick
    assert_equal([[15, 14]], t.t1.to_a.sort)

    t.t2 <+ [[5, 11]]
    assert_raises(Bud::KeyConstraintError) { t.tick }
  end

  def test_poset_delta
    t = PosetDelta.new
    t.t1 <+ [[5, 10], [10, 12]]
    t.tick

    assert_equal([[5, 10], [10, 12]].to_set, t.t3.to_set)
  end
end
