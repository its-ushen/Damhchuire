class HomeController < ApplicationController
  def index; end
  def quickstart; end
  def actions
    @actions = ActionOracle::ActionLibrary.actions
  end
def manage_actions; end
  def credentials; end
end
