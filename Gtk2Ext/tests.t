#! /gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/ebelter/dev/svn/perl_modules';

use Gtk2Ext::CheckButtonCrate;
use Gtk2Ext::RadioButtonCrate;
use Gtk2Ext::Dialogs;
use Gtk2Ext::Info;
use Gtk2Ext::PackingFactory;
use Gtk2Ext::Utils;
use Data::Dumper;
use Finfo::Logging 'info_msg';
use Getopt::Long;

my $dialogs = Gtk2Ext::Dialogs->instance;
my $info = Gtk2Ext::Info->instance;
my $utils = Gtk2Ext::Utils->instance;
my $factory = Gtk2Ext::PackingFactory->instance;

my %opts;
my @dialog_test_types = (qw/ all msg file text stock color cbc rbc slist win /);
GetOptions
(
    \%opts,
    @dialog_test_types,
)
    or die;

$opts{all} = 1 unless %opts;

if ( $opts{msg} or $opts{all} )
{
    foreach my $type ( $info->msg_dialog_types )
    {
        my $method = $type . '_dialog';

        main->info_msg( $dialogs->$method("Testing $type") );
        next;

        my $response = $dialogs->$method("Testing $type");
        main->info_msg( sprintf('Test %s msg dialog: %s', $type, $response || 'none') );
    }
}

if ( $opts{text} or $opts{all} )
{
    my $response = $dialogs->text_dialog
    (
        title => 'Testing Text Dialog',
        text => '',
    );
    main->info_msg( sprintf('Text dialog: %s', $response || 'none') );
}

if ( $opts{file} or $opts{all} )
{
    foreach my $type (qw/ new exists dir /)
    {
        my $response = $dialogs->file_dialog
        (
            title => "Testing File Dialog ($type)",
            type => $type,
        );
        main->info_msg( sprintf('File dialog (%s): %s', $type, $response || 'none') );
    }
}

if ( $opts{color} or $opts{all} )
{
    my $colors = $dialogs->color_display_dialog
    (
        colors => [ grep { defined } map { $_->{name} } $info->colors ],
    );
    main->info_msg( Dumper($colors) );
}

if ( $opts{stock} or $opts{all} )
{
    my $stock_id = $dialogs->stock_id_dialog;
    main->info_msg( sprintf('Stock Dialog: %s', $stock_id || 'none') );
}

if ( $opts{rbc} or $opts{all} )
{
    my $rbc = Gtk2Ext::RadioButtonCrate->new
    (
        orient => 'v',
        button_params =>
        [
        {
            name => 'nala',
            events => { clicked => sub{ main->info_msg("merged event!") } },
            ecrates =>
            [
            {
                name => 'sweet',
                label => 'Is she the sweetest?',
                type => 'y_or_n',
                default => 'yep',
            },
            ],
        },
        {
            name => 'simba',
            ecrates =>
            [
            {
                name => 'cute',
                label => 'Is he the cutest?',
                type => 'y_or_n',
                default => 'yep',
            },
            {
                name => 'color',
                label => 'What color is he?',
                type => 'not_blank',
                default => '',
            },
            ],
        },
        ],
    );

    my $value = $dialogs->rb_crate_dialog
    (
        title => 'Radio Button Crate Test',
        rb_crate => $rbc,
    );

    main->info_msg("Radio Button Crate:\n".Dumper($value));
}

if ( $opts{cbc} or $opts{all} )
{
    my $cbc = Gtk2Ext::CheckButtonCrate->new
    (
        orient => 'v',
        button_params =>
        [
        {
            name => 'nala',
            events => { clicked => sub{ main->info_msg("merged event!") } },
            ecrates => 
            [
            {
                name => 'sweet',
                label => 'Is she the sweetest?',
                type => 'y_or_n',
                default => 'yep',
            },
            ],
        },
        {
            name => 'simba',
            ecrates =>
            [
            {
                name => 'cute',
                label => 'Is he the cutest?',
                type => 'y_or_n',
                default => 'yep',
            },
            {
                name => 'color',
                label => 'What color is he?',
                type => 'not_blank',
                default => '',
            },
            ],
        },
        ],
    );

    my $value = $dialogs->cb_crate_dialog
    (
        title => 'Check Button Crate Test',
        cb_crate => $cbc,
    );

    main->info_msg("Check Button Crate:\n".Dumper($value));
}

if ( $opts{slist} or $opts{all} )
{
    my $r = $dialogs->slist_dialog
    (
        title => 'Testing SList Dialog',
        sel_mode => 'multiple',
        columns => [qw/ Name text Cute text Sweet text Age int /],
        data =>
        [
        [qw/ Simba yes yep 3 /],
        [qw/ Nala yes DEFINITELY 6/],
        ],
    );

    main->info_msg("Testing SList Dialog");
}

if ( $opts{win} || $opts{all} )
{
    my $win = $factory->create_window
    (
        title => 'Test waiting cursor',
        h => 300,
        v => 300,
    );

    my $box = $factory->add_box
    (
        parent => $win,
        type => 'v',
    );
    
    $factory->add_button
    (
        parent => $box,
        text => 'Activate Waiting Cursor',
        events =>
        {
            clicked => sub{ $utils->waiting_cursor($win); sleep(5); },
        },
    );

    $factory->add_sep(parent => $box);

    $factory->add_button
    (
        parent => $box,
        stock => 'gtk-quit',
        events =>
        {
            clicked => sub{ $win->destroy; $utils->gtk2_quit; },  
        },
    );

    $utils->gtk2_main;

    main->info_msg("Testing Window");
}

exit(0);

=pod

=head1 Tests

This script tests the classes in this directory (App/UI/Gtik2/Ex) and it's sub-directories.

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

