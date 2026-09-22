require "test_helper"

class EagerLoadTest < RecordablesTest
  def test_the_gem_eager_loads_without_errors
    Zeitwerk::Loader.eager_load_all
  end

  def test_every_public_constant_is_reachable
    assert Recordables::Recordable
    assert Recordables::Recording
    assert Recordables::Macros
    assert Recordables::GeneratorHelpers
    assert Recordables::Railtie
  end
end
