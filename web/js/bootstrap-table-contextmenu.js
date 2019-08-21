/**
 * @author David Graham <prograhammer@gmail.com>
 * @version v1.1.4
 * @link https://github.com/prograhammer/bootstrap-table-contextmenu
 */

!function($) {

    'use strict';

    $.extend($.fn.bootstrapTable.defaults, {
        // Option defaults
        contextMenu: undefined,
        contextMenuTrigger: 'right',
        contextMenuAutoClickRow: true,
        contextMenuButton: undefined,
        beforeContextMenuRow: function (e, row, buttonElement) {
            // return false here to prevent menu showing
        },
        // Event default handlers
        onContextMenuItem: function (row, $element) {
            return false;
        },
        onContextMenuRow: function (row, $element) {
            return false;
        }
    });
	
	// Methods
    $.fn.bootstrapTable.methods.push('showContextMenu');

	// Events
    $.extend($.fn.bootstrapTable.Constructor.EVENTS, {
        'contextmenu-item.bs.table': 'onContextMenuItem',
        'contextmenu-row.bs.table': 'onContextMenuRow'
    });

    var BootstrapTable = $.fn.bootstrapTable.Constructor,
        _initBody = BootstrapTable.prototype.initBody;

    BootstrapTable.prototype.initBody = function () {

        // Init Body
        _initBody.apply(this, Array.prototype.slice.apply(arguments));

        // Init Context menu
        if (this.options.contextMenu || this.options.contextMenuButton || this.options.beforeContextMenuRow) {
            this.initContextMenu();
        }
    };

    // Init context menu
    BootstrapTable.prototype.initContextMenu = function () {
        var that = this;

        // Context menu on Right-click
        if (that.options.contextMenuTrigger == 'right' || that.options.contextMenuTrigger == 'both') {
            that.$body.find('> tr[data-index]').off('contextmenu.contextmenu').on('contextmenu.contextmenu', function (e) {            	
                var rowData = that.data[$(this).data('index')],
                    beforeShow = that.options.beforeContextMenuRow.apply(this, [e, rowData, null]);

                if(beforeShow !== false){
                    that.showContextMenu({event: e});
                }
                return false;
            });
        }

        // Context menu on Left-click
        if (that.options.contextMenuTrigger == 'left' || that.options.contextMenuTrigger == 'both') {
            that.$body.find('> tr[data-index]').off('click.contextmenu').on('click.contextmenu', function (e) {            	
                var rowData = that.data[$(this).data('index')],
                    beforeShow = that.options.beforeContextMenuRow.apply(this, [e, rowData, null]);

                if(beforeShow !== false){
                    that.showContextMenu({event: e});
                }
                return false;
            });
        }

        // Context menu on Button-click
        if (typeof that.options.contextMenuButton === 'string') {
            that.$body.find('> tr[data-index]').find(that.options.contextMenuButton).off('click.contextmenu').on('click.contextmenu', function (e) {                
                var rowData = that.data[$(this).closest('tr[data-index]').data('index')],
                    beforeShow = that.options.beforeContextMenuRow.apply(this, [e, rowData, this]);

                if(beforeShow !== false){
                    that.showContextMenu({event: e, buttonElement: this});
                }
                return false;
            });
        }
    };

    // Show context menu
    BootstrapTable.prototype.showContextMenu = function (params) {
        if(!params || !params.event){ return false; }
        if(params && !params.contextMenu && typeof this.options.contextMenu !== 'string'){ return false; }

        var that = this,
            $menu, screenPosX, screenPosY,
            $tr = $(params.event.target).closest('tr[data-index]'),
            item = that.data[$tr.data('index')];

        if(params && !params.contextMenu && typeof this.options.contextMenu === 'string'){
            screenPosX = params.event.clientX;
            screenPosY = params.event.clientY;
            $menu = $(this.options.contextMenu);
        }
        if(params && params.contextMenu){
            screenPosX = params.event.clientX;
            screenPosY = params.event.clientY;
            $menu = $(params.contextMenu);
        }
        if (params && params.buttonElement) {
            screenPosX = params.buttonElement.getBoundingClientRect().left;
            screenPosY = params.buttonElement.getBoundingClientRect().bottom;
        }

        function getMenuPosition($menu, screenPos, direction, scrollDir) {
            var win = $(window)[direction](),
                scroll = $(window)[scrollDir](),
                menu = $menu[direction](),
                position = screenPos + scroll;

            if (screenPos + menu > win && menu < screenPos)
                position -= menu;

            return position;
        }

        // Bind click on menu item
        $menu.find('li').off('click.contextmenu').on('click.contextmenu', function (e) {
            var rowData = that.data[$menu.data('index')];
            that.trigger('contextmenu-item', rowData, $(this));
        });

        // Click anywhere to hide the menu
        $(document).triggerHandler('click.contextmenu');
        $(document).off('click.contextmenu').on('click.contextmenu', function (e) {
			// Fixes problem on Mac OSX
        	if(that.pageX != e.pageX || that.pageY != e.pageY){
        		$menu.hide();
        		$(document).off('click.contextmenu');
        	}
        });
        that.pageX = params.event.pageX;
        that.pageY = params.event.pageY;

        // Show the menu
        $menu.data('index', $tr.data('index'))
            .appendTo($('body'))
            .css({
                position: "absolute",
                left: getMenuPosition($menu, screenPosX, 'width', 'scrollLeft'),
                top: getMenuPosition($menu, screenPosY, 'height', 'scrollTop'),
                zIndex: 1100
            })
            .show();

        // Trigger events
        that.trigger('contextmenu-row', item, $tr);
        if(that.options.contextMenuAutoClickRow && that.options.contextMenuTrigger == 'right') {
            that.trigger('click-row', item, $tr);
        }
    };


}(jQuery);
