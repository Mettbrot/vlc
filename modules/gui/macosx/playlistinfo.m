/*****************************************************************************
 r playlistinfo.m: MacOS X interface module
 *****************************************************************************
 * Copyright (C) 2002-2004 VideoLAN
 * $Id$
 *
 * Authors: Benjamin Pracht <bigben at videolan dot org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111, USA.
 *****************************************************************************/

/*****************************************************************************
 * Preamble
 *****************************************************************************/

#include "intf.h"
#include "playlistinfo.h"
#include "playlist.h"

/*****************************************************************************
 * VLCPlaylistInfo Implementation
 *****************************************************************************/

@implementation VLCInfo

- (id)init
{
    self = [super init];

    if( self != nil )
    {
        i_item = -1;
        o_selected = NULL;
    }
    return( self );
}

- (void)dealloc
{
    [o_selected release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [o_info_window setExcludedFromWindowsMenu: TRUE];

    [o_info_window setTitle: _NS("Properties")];
    [o_uri_lbl setStringValue: _NS("URI")];
    [o_title_lbl setStringValue: _NS("Title")];
    [o_author_lbl setStringValue: _NS("Author")];
    [o_btn_ok setTitle: _NS("OK")];
    [o_btn_cancel setTitle: _NS("Cancel")];
}

- (IBAction)togglePlaylistInfoPanel:(id)sender
{
    if( [o_info_window isVisible] )
    {
        [o_info_window orderOut: sender];
    }
    else
    {
        i_item = [[[VLCMain sharedInstance] getPlaylist] selectedPlaylistItem];
        o_selected = [[[VLCMain sharedInstance] getPlaylist] selectedPlaylistItemsList];
        [o_selected retain];
        [self initPanel:sender];
    }
}

- (IBAction)toggleInfoPanel:(id)sender
{
    if( [o_info_window isVisible] )
    {
        [o_info_window orderOut: sender];
    }
    else
    {
        intf_thread_t * p_intf = VLCIntf;
        playlist_t * p_playlist = vlc_object_find( p_intf, VLC_OBJECT_PLAYLIST,
                                          FIND_ANYWHERE );

        if (p_playlist)
        {
            i_item = p_playlist->i_index;
            o_selected = [NSMutableArray arrayWithObject:
                            [NSNumber numberWithInt:i_item]];
            [o_selected retain];
            vlc_object_release(p_playlist);
        }
        [self initPanel:sender];
    }
}

- (void)initPanel:(id)sender
{
    intf_thread_t * p_intf = VLCIntf;
    playlist_t * p_playlist;

    p_playlist = vlc_object_find( p_intf, VLC_OBJECT_PLAYLIST,
                                          FIND_ANYWHERE );


    if( p_playlist )
    {
        char *psz_temp;

        /*fill uri / title / author info */
        [o_uri_txt setStringValue:
            ([NSString stringWithUTF8String:p_playlist->
               pp_items[i_item]->input.psz_uri] == nil ) ?
            [NSString stringWithCString:p_playlist->
                pp_items[i_item]->input.psz_uri] :
            [NSString stringWithUTF8String:p_playlist->
                pp_items[i_item]->input.psz_uri]];

        [o_title_txt setStringValue:
            ([NSString stringWithUTF8String:p_playlist->
                pp_items[i_item]->input.psz_name] == nil ) ?
            [NSString stringWithCString:p_playlist->
                pp_items[i_item]->input.psz_name] :
            [NSString stringWithUTF8String:p_playlist->
                pp_items[i_item]->input.psz_name]];

        psz_temp = playlist_GetInfo( p_playlist, i_item ,_("General"),_("Author") );
        [o_author_txt setStringValue: [NSString stringWithUTF8String: psz_temp]];
        free( psz_temp );

        [[VLCInfoTreeItem rootItem] refresh];
        [o_outline_view reloadData];

        vlc_object_release( p_playlist );
    }
    [o_info_window makeKeyAndOrderFront: sender];
}

- (IBAction)infoCancel:(id)sender
{
    [o_info_window orderOut: self];
}


- (IBAction)infoOk:(id)sender
{
    int c;
    intf_thread_t * p_intf = VLCIntf;
    playlist_t * p_playlist = vlc_object_find( p_intf, VLC_OBJECT_PLAYLIST,
                                          FIND_ANYWHERE );
    vlc_value_t val;

    if (p_playlist)
    {
        vlc_mutex_lock(&p_playlist->pp_items[i_item]->input.lock);

        p_playlist->pp_items[i_item]->input.psz_uri =
            strdup([[o_uri_txt stringValue] cString]);
        p_playlist->pp_items[i_item]->input.psz_name =
            strdup([[o_title_txt stringValue] cString]);
        playlist_ItemAddInfo(p_playlist->pp_items[i_item],_("General"),_("Author"), [[o_author_txt stringValue] cString]);

        c = (int)[o_selected count];
        vlc_mutex_unlock(&p_playlist->pp_items[i_item]->input.lock);
        val.b_bool = VLC_TRUE;
        var_Set( p_playlist,"intf-change",val );
        vlc_object_release ( p_playlist );
    }
    [o_info_window orderOut: self];
}

- (int)getItem
{
    return i_item;
}

@end

@implementation VLCInfo (NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)o_mi
{
    BOOL bEnabled = TRUE;

    intf_thread_t * p_intf = VLCIntf;
    input_thread_t * p_input = vlc_object_find( p_intf, VLC_OBJECT_INPUT,
                                                       FIND_ANYWHERE );

    if( [[o_mi title] isEqualToString: _NS("Info")] )
    {
        if( p_input == NULL )
        {
            bEnabled = FALSE;
        }
    }
    if( p_input ) vlc_object_release( p_input );

    return( bEnabled );
}

@end

@implementation VLCInfo (NSTableDataSource)

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return (item == nil) ? [[VLCInfoTreeItem rootItem] numberOfChildren] : [item numberOfChildren];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ([item numberOfChildren] > 0);
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    return (item == nil) ? [[VLCInfoTreeItem rootItem] childAtIndex:index] : [item childAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if ([[tableColumn identifier] isEqualToString:@"0"])
    {
        return (item == nil) ? @"" : (id)[item getName];
    }
    else
    {
        return (item == nil) ? @"" : (id)[item getValue];
    }
}


@end

@implementation VLCInfoTreeItem

static VLCInfoTreeItem *o_root_item = nil;

#define IsALeafNode ((id)-1)

- (id)initWithName: (NSString *)o_item_name value: (NSString *)o_item_value ID: (int)i_id parent:(VLCInfoTreeItem *)o_parent_item
{
    self = [super init];

    if( self != nil )
    {
        o_name = [o_item_name copy];
        o_value = [o_item_value copy];
        i_object_id = i_id;
        o_parent = o_parent_item;
        i_item = [[[VLCMain sharedInstance] getInfo] getItem];
    }
    return( self );
}

+ (VLCInfoTreeItem *)rootItem {
    if (o_root_item == nil) o_root_item = [[VLCInfoTreeItem alloc] initWithName:@"main" value: @"" ID: 0 parent:nil];
    return o_root_item;
}

- (void)dealloc
{
    if (o_children != IsALeafNode) [o_children release];
    [o_name release];
    [super dealloc];
}

/* Creates and returns the array of children
 * Loads children incrementally */
- (NSArray *)children
{
    if (o_children == NULL)
    {
        intf_thread_t * p_intf = VLCIntf;
        playlist_t * p_playlist = vlc_object_find( p_intf, VLC_OBJECT_PLAYLIST,
                                          FIND_ANYWHERE );
        int i;

        if (p_playlist)
        {
            if (i_item > -1)
            {
                if (self == o_root_item)
                {
                    o_children = [[NSMutableArray alloc] initWithCapacity:p_playlist->pp_items[i_item]->input.i_categories];
                    for (i = 0 ; i<p_playlist->pp_items[i_item]->input.i_categories ; i++)
                    {
                        [o_children addObject:[[VLCInfoTreeItem alloc]
                            initWithName: [NSString stringWithUTF8String:
                                p_playlist->pp_items[i_item]->input.
                                pp_categories[i]->psz_name]
                            value: @""
                            ID: i
                            parent: self]];
                    }
                }
                else if (o_parent == o_root_item)
                {
                    o_children = [[NSMutableArray alloc] initWithCapacity:
                        p_playlist->pp_items[i_item]->input.
                        pp_categories[i_object_id]->i_infos];
                    for (i = 0 ; i<p_playlist->pp_items[i_item]->input.
                           pp_categories[i_object_id]->i_infos ; i++)
                    {
                        [o_children addObject:[[VLCInfoTreeItem alloc]
                        initWithName: [NSString stringWithUTF8String:
                                p_playlist->pp_items[i_item]->input.
                                pp_categories[i_object_id]->
                                pp_infos[i]->psz_name]
                            value: [NSString stringWithUTF8String:
                                p_playlist->pp_items[i_item]->input.
                                pp_categories[i_object_id]->
                                pp_infos[i]->psz_value]
                            ID: i
                            parent: self]];
                    }
                }
                else
                {
                    o_children = IsALeafNode;
                }
            }
            vlc_object_release(p_playlist);
        }
    }
    return o_children;
}

- (NSString *)getName
{
    return o_name;
}

- (NSString *)getValue
{
    return o_value;
}

- (VLCInfoTreeItem *)childAtIndex:(int)i_index {
    return [[self children] objectAtIndex:i_index];
}

- (int)numberOfChildren {
    id i_tmp = [self children];
    return (i_tmp == IsALeafNode) ? (-1) : (int)[i_tmp count];
}

/*- (int)selectedPlaylistItem
{
    return i_item;
}
*/
- (void)refresh
{
    i_item = [[[VLCMain sharedInstance] getInfo] getItem];
    if (o_children != NULL)
    {
        [o_children release];
        o_children = NULL;
    }
}

@end

