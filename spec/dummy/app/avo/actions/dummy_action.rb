class DummyAction < Avo::BaseAction
  self.name = "Dummy action"
  self.standalone = true

  def handle(**args)
    # Do something here
    succeed 'Yup'
  end
end
