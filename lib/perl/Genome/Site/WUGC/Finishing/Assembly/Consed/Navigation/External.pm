package Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation::External;

use strict;
use warnings;

use Finfo::Std;

use Gtk2Ext::Dialogs;
use Gtk2Ext::EntryCrate;
use Gtk2Ext::PackingFactory;
use Gtk2Ext::Utils;
use Data::Dumper;
use File::Basename;
use IO::File;
use IO::Socket;
use Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation::Reader;
use Getopt::Long;
use POE::Session;
use POE::Kernel { loop => 'Glib' };

my %acenav :name(acenav:r)
    :clo('acenav=s') 
    :desc('Multi Ace Navigation file, use \'nav2acenav\' to convert a regular nav file to a acenav file');
my %break :name(break:o) 
    :isa('int pos') 
    :clo('break=i') 
    :desc('Break each navigation into sections of (x) bases each');

# priv
my %window :name(_window:p)
    :isa(object);
my %slist :name(_slist:p)
    :isa(object);
my %row :name(_row:p) 
    :isa('int non_neg') 
    :default(0);
my %frame :name(_slist_frame:p);
my %prefs :name(_preferences:p)
    :ds(hashref) 
    :default({ interval => 5, use_phds => 'no', warn_when_opening_acefile => 'no', });
my %max :name(_max:p)
    :isa('int pos');
my %aces :name(_aces:p)
    :ds(hashref)
    :empty_ok(1)
    :default({});
my %port :name(_port:p)
    :default(1024);

sub run
{
    my $self = shift;

    POE::Session->create
    (
        inline_states =>
        {
            _start => sub{ shift; $self->_ui_start(@_) },
            ev_goto => sub{ shift; $self->_ui_goto(@_) },
            ev_prev => sub{ shift; $self->_ui_prev(@_) },
            ev_next => sub{ shift; $self->_ui_next(@_) },
            ev_run => sub{ shift; $self->_ui_run(@_) },
            ev_stop => sub{ shift; $self->_ui_stop(@_) },
        }
    )
        or return;

    POE::Kernel->run();

    return 1;
}

sub gtk2_utils : PRIVATE
{
    return Gtk2Ext::Utils->instance;
}

sub gtk2_dialogs : PRIVATE
{
    return Gtk2Ext::Dialogs->instance;
}

sub factory : PRIVATE
{
    return Gtk2Ext::PackingFactory->instance;
}

sub _ui_start
{
    my ($self, $session, $kernel) = @_[ OBJECT, SESSION, KERNEL ];

    my $factory = $self->factory;

    my $window = $factory->create_window
    (
        title => 'Consed External Navigator',
        h => 700,
        v => 350,
        border_width => 15,
    )
        or return;

    $self->_window($window);

    $kernel->signal_ui_destroy($window);

    my $vbox = $factory->add_box(parent => $window, type => 'v');

    my $menu = $factory->add_menu
    (
        parent => $vbox,
        expand => 0,
        fill => 0,
        menu_tree =>
        [
        File => 
        {
            item_type => '<Branch>',
            children =>
            [
            Quit => 
            {
                item_type => '<StockItem>',
                extra_data => 'gtk-quit',
                callback => sub{ $self->_window->destroy; $self->gtk2_utils->gtk2_quit; exit 0 },
                accelerator => '<ctrl>Q',
            },
            ],
        },
        Options =>
        {
            item_type => '<Branch>',
            children =>
            [
            'Reopen Ace' =>
            {
                callback => sub{ $self->_reopen_ace },
                item_type => '<StockItem>',
                extra_data => 'gtk-refresh',
            },
            Separator =>
            {
                item_type => '<Separator>'
            },
            'Preferences' =>
            {
                callback => sub{ $self->_change_preferences_select },
                item_type => '<StockItem>',
                extra_data => 'gtk-preferences',
            },
            ],
        },
        Help =>
        {
            item_type => '<LastBranch>',
            children => 
            [
            About =>
            {
                callback => sub{},
                item_type => '<StockItem>',
                extra_data => 'gtk-about',
            },
            'Wiki Fin FAQ' => 
            {
                callback => sub
                {
                    $self->gtk2_dialogs->info_dialog("Launching firefox, please wait");
                    my $pid = fork();
                    if ($pid)
                    { 
                        # parent falls thru
                    }
                    elsif (defined($pid))
                    {
                        exec("firefox http://gscweb.gsc.wustl.edu/wiki/External_nav_Fin_FAQs")
                            or $self->error_msg("Could not launch firefox: $!");
                    }
                    else
                    {
                        $self->gtk2_error_dialog("Could not fork firefox process, bummer");
                    }
                },
                item_type => '<StockItem>',
                extra_data => 'gtk-info',
            },
            'Wiki Module Documentation' => 
            {
                callback => sub
                {
                    $self->gtk2_dialogs->info_dialog("Launching firefox, please wait");
                    my $pid = fork();
                    if ($pid)
                    { 
                        # parent falls thru
                    }
                    elsif (defined($pid))
                    {
                        exec("firefox http://gscweb.gsc.wustl.edu/wiki/SoftwareDevelopment:Perl_Modules/Genome::Site::WUGC::Finishing::Assembly::Consed::Navigator::External")
                            or $self->error_msg("Could not launch firefox: $!");
                    }
                    else
                    {
                        $self->gtk2_error_dialog("Could not fork firefox process, bummer");
                    }
                },
                item_type => '<StockItem>',
                extra_data => 'gtk-info',
            },
            ],
        },
        ],
    );

    $window->add_accel_group( $menu->{accel_group} );

    $self->_slist_frame
    (
        $factory->add_frame
        (
            parent => $vbox,
            text => "Current File: " . basename($self->acenav),
        )
    );

    $self->_slist
    (
        $factory->add_slist
        (
            parent => $factory->add_sw
            (
                parent => $self->_slist_frame,
                h => 700,
                v => 150,
                fill => 1,
                expand => 1,
            ),
            columns => [qw/ Dir text Ace text Contig text Position int Comment text /],
            events =>
            {
                'row_activated' => $session->callback('ev_goto'),
            },
        )
    );

    $self->_slist->get_column(0)->set_visible(0);
    
    $self->_load_acenav
        or return;

    my $bbox = $factory->add_bbox
    (
        parent => $factory->add_frame
        (
            parent => $vbox,
            shadow => 'in',
            expand => 0,
        ),
        type => 'h', 
        layout => 'spread',
        border_width => 8,
        homogen => 1,
    );

    $factory->add_button
    (
        parent => $bbox,
        stock => 'gtk-go-back',
        events => { 'clicked' => $session->callback("ev_prev") },
    );

    $factory->add_button
    (
        parent => $bbox,
        stock => 'gtk-jump-to',
        events => { 'clicked' => $session->callback("ev_goto") },
    );
    
    $factory->add_button
    (
        parent => $bbox,
        stock => 'gtk-go-forward',
        events => { 'clicked' => $session->callback("ev_next") },
    );

    $factory->add_button
    (
        parent => $bbox,
        stock => 'gtk-media-play',
        events => { 'clicked' => $session->callback("ev_run") },
    );

    $factory->add_button
    (
        parent => $bbox,
        stock => 'gtk-stop',
        events => { 'clicked' => $session->callback("ev_stop") },
    );

    $self->gtk2_utils->gtk2_main;

    return 1;
}

sub _open_acefile : PRIVATE
{
    my ($self, $af) = @_;

    return unless Finfo::Validate->validate
    (
        attr => 'ace to open',
        value => $af,
        type => 'input_file',
        err_cb => sub{ $self->gtk2_dialogs->display_error(@_); },
    );

    my $port = $self->_aces->{$af};

    if ( $port )
    {
        my $socket = $self->_create_socket($port);
        return $socket if $socket;
    }

    if ( $self->_preferences->{warn_when_opening_acefile} =~ /^y/ )
    {
        return unless $self->gtk2_dialogs->question_dialog("Continue to open acefile?") eq 'yes';
    }
    
    $port = $self->_next_port_number;
    
    $self->_aces->{$af} = $port;

    system
    (
        sprintf
        (
            "perl /gscuser/ebelter/dev/svn/finishing/consed/new-cs.pl --cwd --ace %s --socket %s %s",
            $af,
            $port,
            ( $self->_preferences->{use_phds} =~ /^n/ ) ? '--nophd' : '',
        )
    );

    return; # return undef because we opened an ace, this means the 'scroll' function 
    # needs to be called again
}

sub _reopen_ace : PRIVATE
{
    my $self = shift;

    my ($row_data) = $self->gtk2_utils->get_selected_data_in_slist($self->_slist);

    unless ( $row_data )
    {
        $self->gtk2_dialogs->info_dialog("Please select a location");
        return;
    }
    
    my $af = sprintf('%s/%s', $row_data->[0], $row_data->[1]);

    if ( $self->_open_acefile($af) )
    {
        if
        ( 
            $self->gtk2_dialogs->question_dialog
            (
                "Ace ($row_data->[1]) is already open, really reopen?"
            ) eq 'yes'
        )
        {
            delete $self->_aces->{$af} if exists $self->_aces->{$af};
            return $self->_open_acefile($af);
        }
    }
}

sub _next_port_number
{
    my $self = shift;

    my $port = $self->_port;

    return $self->_port( ++$port );
}

sub _create_socket : PRIVATE
{
    my ($self, $port) = @_;

    return IO::Socket::INET->new('localhost:' . $port);
}

sub _load_acenav : PRIVATE
{
    my $self = shift;

    my $file = $self->acenav;
    my $fh = IO::File->new("< $file");
    $self->fatal_msg("Can't open file ($file): $!")
        and return unless $fh;
    my $reader = Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation::Reader->new
    (
        io => $fh,
        return_as_objs => 1,
    )
        or return;
    
    my $count = -1;
    while ( my $nav = $reader->next )
    {
        $self->fatal_msg
        (
            sprintf
            (
                'Each navigation in file (%s) is required to have an acefile.  Please add acefiles to this navigation file manually or by using \'nav2acenav\'', 
                $self->acenav
            )
        ) unless $nav->acefile;
        
        $count++;
        my $start = $nav->start;
        while ( 1 )
        {
            my ($ace, $dir) = File::Basename::fileparse( $nav->acefile );

            $self->gtk2_utils->add_data_to_slist
            (
                $self->_slist,
                [ $dir, $ace, $nav->contig_name, $start, $nav->description ],
            );
            last unless $self->break; # not breaking into segments
            $start += $self->break;
            last if $start > $nav->end;
        }
    }

    $self->_max($count);

    return 1;
}

sub _change_preferences_select : PRIVATE
{
    my ($self) = @_;

    my @ecrates;
    push @ecrates, Gtk2Ext::EntryCrate->new
    (
        name => 'interval', 
        label => 'Time Interval', 
        type => 'int_gte',
        options => [qw/ 5 /],
        default => $self->_preferences->{interval},
    );

    push @ecrates, Gtk2Ext::EntryCrate->new
    (
        name => 'warn_when_opening_acefile', 
        label => 'Warn when opening an acefile?', 
        type => 'y_or_n',
        default => $self->_preferences->{warn_when_opening_acefile},
    );
 
    push @ecrates, Gtk2Ext::EntryCrate->new
    (
        name => 'use_phds', 
        label => 'Open acefile with phds?', 
        type => 'y_or_n',
        default => $self->_preferences->{use_phds},
    );

    my $values = $self->gtk2_dialogs->ecrate_dialog
    (
        title => 'Set Preferences',
        ecrates => \@ecrates,
    );

    return unless defined $values;

    return $self->_preferences($values);
}

sub _scroll : PRIVATE
{
    my ($self, $dir, $ace, $ctg, $pos) = @_;

    my $af = sprintf('%s/%s', $dir, $ace);
    
    my $socket = $self->_open_acefile($af)
        or return;

    return print $socket "Scroll $ctg $pos\n";

    $socket->close;

    return 1;
}

sub _ui_goto
{
    my $self = shift;

    my ($row_data) = $self->gtk2_utils->get_selected_data_in_slist($self->_slist);
    
    unless ( defined $row_data )
    {
        $self->gtk2_dialogs->info_dialog("Please select a location");
        return;
    }

    return $self->_scroll(@$row_data);
}

sub _ui_next
{
    my ($self) = @_;

    my ($row) = $self->gtk2_utils->get_selected_indices_in_slist($self->_slist);

    $row = -1 unless defined $row;
    
    return if $row == $self->_max;

    $row++;

    $self->_slist->set_cursor( Gtk2::TreePath->new($row) );

    return _ui_goto(@_);
}

sub _ui_prev
{
    my ($self) = @_;

    my ($row) = $self->gtk2_utils->get_selected_indices_in_slist($self->_slist);

    return if not defined $row or $row == 0;

    $row--;

    $self->_slist->set_cursor( Gtk2::TreePath->new($row) );

    return _ui_goto(@_);
}

sub _ui_run
{
    my ($self, $kernel, $heap) = @_[ 0, KERNEL, HEAP ];

    $kernel->yield('ev_next');

    my ($row) = $self->gtk2_utils->get_selected_indices_in_slist($self->_slist);

    if ( $row == $self->_max )
    {
        _ui_stop(@_);
        $self->gtk2_dialogs->info_dialog("Reached end of navigator");
    }
    else
    {
        $heap->{alarm_id} = $kernel->delay_set("ev_run", $self->_preferences->{interval});
    }

    return 1;
}

sub _ui_stop
{
    my ($self, $kernel, $heap) = @_[ 0, KERNEL, HEAP ];

    $kernel->alarm_remove($heap->{alarm_id});
    
    return 1;
}

1;

=pod

=head1 Name

Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation::ConvertFromList

=head1 Synopsis

=head1 Usage

 use Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation::External;

 my $ex_nav = Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation::External->new
 (
    acenav => $acefile_navigator, # opt
    break => 100, # opt - breaks each navigation location into this many base pairs
 )
    or die;

 $ex_nav->run;

=head1 Methods

=head2 run

 $ex_nav->run;

=over

=item I<Synopsis>   Starts the nbavigator program

=item I<Params>     none

=item I<Returns>    boolean (true on success)

=back

=head1 See Also

=over

=item consed

=item Genome::Site::WUGC::Finishing::Assembly::Consed::Navigation directory

=item nav2acenav(.pl)

=item Gtk2

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/branches/adukes/AssemblyRefactor/Consed/Navigation/External.pm $
#$Id: External.pm 29586 2007-10-29 15:46:09Z ebelter $

