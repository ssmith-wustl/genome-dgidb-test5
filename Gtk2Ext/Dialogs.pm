package Gtk2Ext::Dialogs;

use strict;
use warnings;

use base 'Finfo::Singleton';

require Cwd;
use Data::Dumper;
use Gtk2Ext::Info;
use Gtk2Ext::PackingFactory;
use Gtk2Ext::Utils;

sub title
{
    return Gtk2Ext::Info->default_title;
}

sub factory
{
    return Gtk2Ext::PackingFactory->instance;
}

sub info
{
    return Gtk2Ext::Info->instance;
}

sub utils
{
    return Gtk2Ext::Utils->instance;
}

sub stock_id_dialog
{
    my $self = shift;

    my $factory = $self->factory;

    my $d = $factory->create_dialog
    (
        title => 'Stock Item Types',
        buttons => [qw/ ok cancel /],
        h => 300,
        v => 500,
    );

    my $vbox = $factory->add_box
    (
        parent => $factory->add_sw(parent => $d->vbox, expand => 1),
        type => 'v',
    );
    
    my @stock_ids = $self->info->stock_ids;

    my $picked_type = $stock_ids[0];
    foreach my $type ( @stock_ids )
    {
        $factory->add_button
        (
            parent => $vbox,
            stock => $type,
            events => 
            {
                clicked => sub{ $picked_type = $type },
            },
        );
    }

    if ( $d->run eq 'ok' )
    {
        return $picked_type;
    }

    return;
}

# Color
sub color_selection_dialog
{
    my ($self, $color) = @_;

    my $dialog = Gtk2::ColorSelectionDialog->new("Select Color"); 
    if ( ref($color) and $color->isa('Gtk2::Gdk::Color') )
    {
        $dialog->colorsel->set_current_color($color);
    }
    elsif ( $color )
    {
        my $gdk_color = $self->utils->create_color($color);
        $dialog->colorsel->set_current_color($gdk_color) if $gdk_color;
    }
    
    my $response = $dialog->run; 
    
    if ( $response eq 'ok' )
    {
        my $color = $dialog->colorsel->get_current_color;
        $dialog->destroy;
        return $color;
    }
    else
    {
        $dialog->destroy;
    }
}

sub color_display_dialog
{
    my ($self, %p) = @_;

    my $colors = $p{colors};
    
    Finfo::Validate->validate
    (
        attr => 'colors to display',
        value => $colors,
        type => 'non_empty_aryref',
        err_cb => $self,
    );
    
    my $factory = $self->factory;
    my $utils = $self->utils;

    my $v = (scalar @$colors) * 35 + 75;
    $v = 500 if $v > 500;

    my $d = $factory->create_dialog
    (
        title => $p{title} || "Change Colors",
        parent => $p{parent} || undef,
        flags => [qw/ modal destroy-with-parent /],
        buttons => [qw/ apply cancel /],
        h => 400,
        v => $v,
    );

    my $box = $factory->add_box
    (
        parent => $factory->add_sw(parent => $d->vbox, expand => 1),
        type => 'v',
        homogen => 1,
    );

    for ( my $i = 0; $i < @$colors; $i++ )
    {
        my $j = $i;
        
        my $hbox = $factory->add_box(parent => $box, type => 'h');

        my $entry = $factory->add_entry
        (
            parent => $hbox,
            edit => 0,
        );

        $utils->add_color_to_widget
        (
            widget => $entry, 
            base => $colors->[$i],
        );
        
        my $button = $factory->add_button
        (
            parent => $hbox,
            text => 'Change Color #' . ($i + 1),
            events => 
            {
                "clicked" => sub
                {
                    my ($button) = @_;

                    my $return_color = $self->color_selection_dialog($colors->[$j]);
                    if ( $return_color )
                    {
                        $utils->add_color_to_widget
                        (
                            widget => $entry, 
                            base => [ $return_color->red, $return_color->green, $return_color->blue ],
                        );

                        $colors->[$j] = [ $return_color->red, $return_color->green, $return_color->blue ];
                    }
                },
            },
        );

    }

    while (1)
    {
        my $r = $d->run;
        $d->destroy;

        return ( $r eq 'apply' ) ? $colors : undef;
    }
}

# Warnings
sub _set_and_display_warning : PRIVATE
{
    my ($self, $msg) = @_;
    
    $self->fatal_msg("No message sent to _set_and_display_warning")
        and return unless defined $msg;
    
    $self->warn_msg($msg);

    return $self->warning_dialog($msg);
}

sub _set_and_display_error : PRIVATE
{
    my ($self, $msg) = @_;
    
    $self->fatal_msg("No message sent to _set_and_display_error")
        and return unless defined $msg;
    
    $self->warn_msg($msg);

    return $self->warning_dialog($msg);
}

sub _set_and_display_error_about_invalid_params : PRIVATE
{
    my ($self, $method, @keys) = @_;
    
    $self->fatal_msg("No invalid param sent to _set_and_display_error_about_invalid_params")
        and return unless @keys;
    
    my $msg = "Unkown params sent to $method\: " . join(', ', @keys);

    $self->error_msg($msg);

    return $self->error_dialog($msg);
}

# Messages
sub _message_dialog : PRIVATE
{
    my ($self, $parent, $icon, $msg, $button_type) = @_;

    $self->_set_and_display_warning("No message sent to dsiplay in $icon dialog")
        and return unless defined $msg;

    my $text = "               \n$msg               \n";

    my $dialog = Gtk2::MessageDialog->new_with_markup
    (
        $parent,
        [qw/modal destroy-with-parent/],
        $icon,
        $button_type,
        sprintf "$text"
    );

    my $ret_val = $dialog->run;

    $dialog->destroy;

    return $ret_val;
}

sub warning_dialog
{
    my ($self, $message, $parent) = @_;

    return $self->_message_dialog($parent, "warning", $message, "ok");
}

sub error_dialog
{
    my ($self, $message, $parent) = @_;

    return $self->_message_dialog($parent, "error", $message, "ok");
}

sub info_dialog
{
    my ($self, $message, $parent) = @_;

    return $self->_message_dialog($parent, "info", $message, "ok");
}

sub question_dialog
{
    my ($self, $message, $parent) = @_;

    return $self->_message_dialog($parent, "question", $message, "yes-no");
}

# radio/check button crate dialogs
sub _button_crate_dialog : PRIVATE
{
    my ($self, %p) = @_;

    my $type = delete $p{type};
    my $bc = delete $p{$type};
    my $bc_class = sprintf('Gtk2Ext::%sButtonCrate', ( $type eq 'rb_crate' ) ? 'Radio' : 'Check');

    return unless Finfo::Validate->validate
    (
        attr => "$type to create selector for",
        value => $bc,
        type => 'inherits_from',
        options => [ $bc_class ],
        err_cb => $self,
    );

    my $h = 500;
    my $v = scalar( $bc->get_buttons ) * 45;
    $v  = ( $v > 400 )
    ? 400
    : $v;

    my $dialog = $self->factory->create_dialog
    (
        title => $p{title},
        parent => $p{parent},
        h => $h + 100,
        v => $v + 100, 
        buttons => [qw/ ok cancel /],
    );

    my $pack_method = 'pack_' . $type;
    $self->factory->$pack_method
    (
        parent => $self->factory->add_sw
        (
            parent => $dialog->vbox,
            h => $h,
            v => $v,
            fill => 1,
            expand => 1,
        ),
        $type => $bc,
    );

    while (1)
    {
        my $response = $dialog->run;

        if ($response eq 'ok' )
        {
            my $method = ( $type eq 'rb_crate' )
            ? 'get_entered_values_in_ecrates_for_active_button'
            : 'get_entered_values_in_ecrates_for_active_buttons';

            my ($return, $results) = $bc->$method;

            if ( not defined $return )
            {
                $self->error_dialog("No buttons selected");
            }
            elsif ( $return == 1 )
            {
                $dialog->destroy;
                return $results;
            }
            elsif ( $return == 0 )
            {
                $self->error_dialog( join("\n", @$results) );
            }
        }
        else
        {
            $dialog->destroy;
            return;
        }
    }
}

sub rb_crate_dialog
{
    my $self = shift;

    return $self->_button_crate_dialog
    (
        type => 'rb_crate',
        @_,
    );
}

sub cb_crate_dialog
{
    my $self = shift;

    return $self->_button_crate_dialog
    (
        type => 'cb_crate',
        @_,
    );
}

sub text_dialog 
{   
    my ($self, %p) = @_;

    my $factory = $self->factory;

    my $label;
    if ( exists $p{ques} )
    {
        $p{buttons} = [qw/ yes no /];
        $label = $factory->create_label
        (
            text => $p{ques},
            markup => '<span foreground="blue" size="medium">' . $p{ques} . '</span>',
            reorder => 0,
        );
    }
    else
    {
        $p{buttons} = [qw/ save close /];
    }

    my $dialog = $factory->create_dialog
    (
        title => $p{title} || $self->title,
        parent => $p{parent},
        buttons => $p{buttons},
    );

    my ($buffer, $tview) = $factory->add_basic_text
    (
        parent => $factory->add_sw
        (
            parent => $dialog->vbox,
            h => $p{h},
            v => $p{v},
        ),
        edit => $p{edit},
    );

    my $iter = $buffer->get_start_iter;
    $buffer->create_tag('font', font => 'Courier 12');
    $buffer->insert_with_tags_by_name($iter, $p{text}, 'font') if $p{text};

    if ( $label )
    {
        $factory->pack_or_add_child
        (
            parent => $dialog->action_area,
            child => $label,
            reorder => 0,
        );
    }
    
    while (1)
    {
        my $response = $dialog->run;

        if ( $response eq 'yes' )
        {
            $dialog->destroy;
            return $response;
        }
        elsif ( $response eq 'accept' )
        {
            $self->save_text_to_file( $p{text} );
        }
        else
        {
            $dialog->destroy;
            return;
        }
    }
 
    return $dialog;
}

sub ecrate_dialog
{
    my ($self, %p) = @_;
    
    my $ecrates = delete $p{ecrates};
    my $dup_entry = delete $p{dup_entry} || 0;

    return unless Finfo::Validate->validate
    (
        attr => 'ecrates for dialog',
        value => $ecrates,
        type => 'inherits_from_aryref',
        options => [qw/ Gtk2Ext::EntryCrate /],
        err_cb => $self,
    );
    
    my $h = delete $p{h} || 500;
    my $v = scalar(@$ecrates) * 60;
    $v = ( $v > 500 )
    ? 500
    : $v;
    
    my $factory = $self->factory;

    my $dialog = $factory->create_dialog
    (
        title => $p{title},
        parent => $p{parent},
        buttons => [qw/ ok cancel /],
        h => $h + 70,
        v => $v + 70,
    );

    my $vbox = $factory->add_box
    (
        parent => $factory->add_sw
        (
            parent => $dialog->vbox,
            h => $h,
            v => $v
        ),
        type => 'v',
    );

    foreach my $ecrate ( @$ecrates )
    {
        $factory->pack_ecrate
        (
            parent => $vbox,
            ecrate => $ecrate,
        )
            or return;
    }

    RESPONSE:
    while (1)
    {
        my $response = $dialog->run;

        if ($response eq 'ok' )
        {
            my ($values, @errors);

            ECRATES:
            foreach my $ecrate ( @$ecrates )
            {
                my $value = $ecrate->get_entered_value;

                unless ( defined $value )
                {
                    push @errors, $ecrate->short_error_msg;
                    next ECRATES;
                }

                $values->{ $ecrate->name } = $value;
            }

            if ( @errors )
            {
                $self->error_dialog( join("\n", @errors) );
                next RESPONSE;
            }

            $dialog->destroy;
            return $values;
        }
        else
        {
            $dialog->destroy;
            return;
        }
    }
}

sub file_dialog
{
    my ($self, %p) = @_;

    my $dir = delete $p{dir};
    my $pwd = Cwd::getcwd();
    chdir $dir if defined $dir and -d $dir;

    my $type = (defined $p{type} and $p{type} =~ /exists|new|dir/)
    ? delete $p{type}
    : 'new';

    my %titles = 
    (
        dir => 'Please Select Directory',
        'exists' => 'Please Select a File',
        'new' => 'Please Eneter a New File',
    );
    
    my $title = ( exists $p{title} )
    ? delete $p{title}
    : $titles{$type};

    my $fs = Gtk2::FileSelection->new($titles{$type});

    my $pattern = delete $p{pattern};
    $fs->complete($p{pattern}) if $pattern;

    $self->fatal_msg("Unknown params sent to create_window:" . join(', ', keys %p)) if %p;
    
    while (1)
    {
        my $response = $fs->run;

        if ($response eq "ok")
        {
            my ($file) = $fs->get_selections;

            if (defined $file and $type eq 'new')
            {
                if (-e $file and !-d $file)
                {
                    if ($self->question_dialog("File exists, overwrite?") eq "yes")
                    {
                        $fs->destroy;
                        chdir $pwd;
                        return $file;
                    }
                }
                elsif (!-e $file and !-d $file)
                {
                    $fs->destroy;
                    chdir $pwd;
                    return $file;
                }
                else
                {
                    $self->error_dialog("Please select a new file");
                }
            }
            elsif (defined $file and $type eq 'exists')
            { 
                if (-e $file and !-d $file)
                {
                    $fs->destroy;
                    chdir $pwd;
                    return $file;
                }
                else
                {
                    $self->error_dialog("Please select a file, not a directory");
                }
            }
            elsif (defined $file and $type eq 'dir')
            {
                if (-d $file)
                {
                    $fs->destroy;
                    chdir $pwd;
                    return $file;
                }
                else
                {
                    $self->error_dialog("Please select a directory, not a file");
                }
            }
            else
            {
                $self->error_dialog("Please select a file");
            }
        }
        else
        {
            $fs->destroy;
            chdir $pwd;
            return;
        }
    }
}

# Simple List
sub slist_dialog
{
    my ($self, %p) = @_;

    my $v = delete $p{v} || 600;
    my $h = delete $p{h} || 600;
    my $cols = delete $p{columns};
    my $data = delete $p{data};

    Finfo::Validate->validate
    (
        attr => 'slist columns',
        value => $cols,
        type => 'non_empty_aryref',
        err_cb => $self,
    );
 
    return unless Finfo::Validate->validate
    (
        attr => 'slist data',
        value => $data,
        type => 'non_empty_aryref',
        err_cb => sub{ $self->_set_and_display_warning(@_) },
    );
    
    my $factory = $self->factory;

    my $dialog = $factory->create_dialog
    (
        title => delete $p{title} || $self->title,
        h => $h,
        v => $v,
        buttons => [qw/ save close /],
    );

    my $slist = $factory->add_slist
    (
        parent => $factory->add_sw
        (
            parent => $dialog->vbox,
            expand => 1,
        ),
        sel_mode => delete $p{sel_mode},
        columns => $cols,
        data => $data,
    );

    $self->_set_and_display_error_about_invalid_params('slist_dialog', keys %p)
        and return if  %p;

    while (1)
    {
        my $response = $dialog->run;

        if ( $response eq 'accept' )
        {
            my $text;
            if ( $self->utils->get_slist_selected_indices($slist) 
                    and $self->question_dialog('Save just selected data?') eq 'yes' )
            {
                $text = $self->utils->get_slist_selected_data_as_delineated_string($slist, '\t')
            }
            else
            {
                $text = $self->utils->get_all_slist_data_as_delineated_string($slist, '\t');
            }

            next unless $text;

            $self->save_text_to_file($text)
        }
        else
        {
            $dialog->destroy;
            return;
        }
    }
}

1;

=pod

B<Sorry, documentation is not complete>

=head1 Name

Gtk2Ext::Dialogs

=head1 Synopsis

This class has methods that simplify basic Gtk2 dialog creation and event handling.

=head1 Usage

 use Gtk2Ext::Dialogs;

 my $dialogs = Gtk2Ext::Dialogs->instance();

 # Show a warning
 $dialogs->warning_dialog("Look out!");
 
 # Show text with option to save
 $dialogs->text_dialog
 (
    title => 'Hello World',
    text => 'Hello world!  You are my best friend!',
    edit => 1, # allow editing of text
 );
 
=head1 Methods

=head2 stock_id_dialog

 $dialogs->stock_id_dialog();

=over

=item I<Synopsis>

=item I<Params>     

=item I<Returns>    stock id selected (string)

=back

=head2 color_selection_dialog

 $dialogs->color_selection_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 color_display_dialog

 $dialogs->color_display_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 warning_dialog

 $dialogs->warning_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 error_dialog

 $dialogs->error_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 info_dialog

 $dialogs->info_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 question_dialog

 $dialogs->question_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 rb_crate_dialog

 $dialogs->rb_crate_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 cb_crate_dialog

 $dialogs->cb_crate_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 text_dialog

 $dialogs->text_dialog ();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 ecrate_dialog

 $dialogs->ecrate_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 file_dialog

 $dialogs->file_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head2 slist_dialog

 $dialogs->slist_dialog();

=over

=item I<Synopsis>

=item I<Params>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
