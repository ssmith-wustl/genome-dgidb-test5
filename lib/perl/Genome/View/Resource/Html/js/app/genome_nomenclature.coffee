# Rewrote excellent intro to Backbone.js http://arturadib.com/hello-backbonejs/ in CoffeeScript

$ ->
      Backbone.sync = (method, model, success, error) ->
        success()

      class Column extends Backbone.Model
        defaults:
          name: 'none'
          type: 'string'
          enumerated_types: []

      class List extends Backbone.Collection
        model: Column

      class ColumnView extends Backbone.View
        tagName: 'li'

        events:
          'click .delete': 'remove'
          'blur input.nomenclature-name': 'nameChanged'
          'change select.column-type-select': 'typeChanged'
          'click .add-new-enum': 'addNewEnum'
          'click .remove-enum': 'removeEnum'
          'blur input.enumerated-type-entry': 'enumChanged'

        nameChanged: ->
          new_name = $(@el).children('.nomenclature-name')[0].value
          @model.set({"name": new_name})

        typeChanged: ->
          type = $(@el).children('.column-type-select')[0].value
          if (type == 'enumerated')
            @model.set({"enumerated_types":['Untitled']}, {"silent": true})
          
          @model.set({"type": type})

        addNewEnum: ->
            types = @model.get "enumerated_types"
            types.push("untitled")
            @model.set({"enumerated_types": undefined}, {"silent" : true})
            @model.set({"enumerated_types": types})

        getEnumIndexForInitiator: (initiator) ->
            parent_row = initiator.parent(".enum-row")[0]
            entire_set = $($(parent_row).parent('.enumerated-choices')).children('.enum-row')
            
            for index in [0...entire_set.length]
                if entire_set.get(index) == parent_row
                    return index

        enumChanged: (k) ->
            initiator = $(k.target)
            index = @getEnumIndexForInitiator(initiator) 
            value = initiator.val()

            types = @model.get "enumerated_types"
            types[index] = value
            @model.set({"enumerated_types": undefined}, {silent: true})
            @model.set({"enumerated_types": types})
            
        removeEnum: (k) ->
            initiator = $(k.target)
           
            index = @getEnumIndexForInitiator(initiator) 
            types = @model.get "enumerated_types"
            types.splice(index, 1)
            @model.set({"enumerated_types": undefined}, {silent: true})
            @model.set({"enumerated_types": types})


        initialize: ->
          _.bindAll @, 'render', 'unrender', 'remove'

          @model.bind 'change', @render
          @model.bind 'remove', @unrender

        render: ->
          item_template = _.template($('#nomenclature-column-template').html(), {model:@model})
          i = $(item_template)
        
          $(@el).html(i)
          $(@el).children(".column-type-select")[0].value = @model.get('type')
          if @model.get('type') == 'enumerated'
            enumerated_template =  _.template($('#nomenclature-column-enumerated-template').html(), {model:@model}) 
            $(@el).append(enumerated_template)
          this

        unrender: ->
          $(@el).remove()

        remove: ->
          this.model.destroy()

      class ListView extends Backbone.View
        el: $('#nomenclature-columns')

        events:
          'click button#add': 'addColumn'

        initialize: ->
          _.bindAll @, 'render', 'addColumn', 'appendColumn'

          @collection = new List
          @collection.bind 'add', @appendColumn
          @collection.bind 'reset', @render

          @render()
        
        appendColumn: (column) ->
          columnView = new ColumnView model: column
          $('ul', @el).append columnView.render().el

        render: ->
          $(@el).html('')
          $(@el).append "<button id='add'>Add column</button>"
          $(@el).append "<ul></ul>"
          _(@collection.models).each (column) -> appendColumn column, @

        addColumn: ->
          column = new Column
          @collection.add column


      listView = new ListView

      $('.save-nomenclature').bind 'click', ->
        json = JSON.stringify(listView.collection)
        alert(json)

      $('.load-nomenclature').bind 'click', ->
        #load_json  = "[{'name':  'hello', 'type': 'string', 'enumerated_types': []},{'name':  'there', 'type': 'enumerated', 'enumerated_types': ['woo', 'there']} ]"
        load_json  = [{"name":"XXXnone","type":"string","enumerated_types":[]}]
        listView.collection.reset(load_json)
        alert('ok')
        alert(JSON.stringify(listView.collection))


          
      
