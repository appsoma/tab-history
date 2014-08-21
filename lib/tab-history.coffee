{Subscriber} = require 'emissary'

# TODO: handle several panes + different modifier keys
class TabHistory
  constructor: (@paneView) ->
    Subscriber.extend @
    @pane = @paneView.model
    @mainModifier = 'ctrlKey'
    @items = []
    @isSwitching = false

  log: () ->
    # console.log { @isSwitching }
    # console.log @items.map((item) -> item.getTitle())

  isActivePane: -> atom.workspace.activePane == @pane

  activate: ->
    @subscribe @paneView, 'keyup', @onKeyUp.bind(@)

    @subscribe @paneView, 'pane:active-item-changed', @onActiveItemChanged.bind(@)
    @subscribe @paneView, 'pane:item-removed', @onItemRemoved.bind(@)

    atom.workspaceView.command "tab-history:previous", @previous.bind(@)
    atom.workspaceView.command "tab-history:next", @next.bind(@)

    @items = [].concat(@pane.items).reverse()
    @pushActiveItem()

  deactivate: ->
    @unsubscribe()

    atom.workspaceView.off 'pane:active-item-changed'
    atom.workspaceView.off 'pane:item-removed'

    @items = []

  onKeyUp: (event) ->
    if !event[@mainModifier] and @switching = true
      @pushActiveItem()
      @switching = false
    return true

  onActiveItemChanged: (event, item) ->
    return unless (item in @pane.items)
    return if @isSwitching
    @pushActiveItem()

  pushActiveItem: ->
    @removePane(@pane.activeItem)
    @items.push(@pane.activeItem)
    @log()

  removePane: (paneItem) ->
    index = @items.indexOf paneItem
    return if index == -1
    @items.splice(index, 1)

  onItemRemoved: (event, item) ->
    @removePane(item)

  previous: (event) ->
    return unless @isActivePane()
    @isSwitching = true
    index = @items.indexOf @pane.activeItem
    if @items.length == 0
      @pane.activateNextItem()
      return
    @pane.activateItem(@items[(index + @items.length - 1) % @items.length])
    @log()

  next: (event) ->
    return unless @isActivePane()
    @isSwitching = true
    index = @items.indexOf atom.workspace.activePaneItem
    if @items.length == 0
      @pane.activatePreviousItem()
      return
    @pane.activateItem(@items[(index + 1) % @items.length])
    @log()

module.exports =
  activate: (state) ->
    @tabHistories = [];
    @paneSubscription = atom.workspaceView.eachPaneView((paneView) =>
      tabHistory = new TabHistory(paneView)
      tabHistory.activate()
      @tabHistories.push(tabHistory)
      onPaneViewRemoved = (event, removedPaneView) =>
        return if paneView != removedPaneView
        tabHistory.deactivate()
        @tabHistories.splice(@tabHistories.indexOf(tabHistory), 1)
      atom.workspaceView.on('pane:removed', onPaneViewRemoved)
    )

  deactivate: ->
    @paneSubscription.off()
    for tabHistory in @tabHistories
      tabHistory.deactivate()
    @tabHistories = null