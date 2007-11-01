package TouchScreen::Session;

use strict;
use warnings;
use Tk;
use base qw(Tk::Toplevel App::Accessor);

TouchScreen::Session->accessorize qw(prior_window 
                                     title 
                                     heading 
                                     fullscreen 
                                     barcode_control
                                     geometry
                                     callback
                                     
                                     window_style
                                     bg_color
                                     font
                                     heading_font

                                     medium_font
                                     big_font
                                     big_clean_font
                                     xl_font
                                     xxl_font
                                     basic_bg
                                     panel_bg
                                     button_bg
                                     active_bg
                                     label_color
                                     );



#-----------------------------------------------

sub set_default_profile{
    my $self = shift;
    my $style = shift;

    $self->medium_font($self->fontCreate(-family => 'helvetica',
                                         -slant => 'roman',
                                         -size => 12));

    $self->big_clean_font($self->fontCreate(-family => 'courier',
                                            -size => 18));
    $self->big_font($self->fontCreate(-family => 'times',
                                      -slant => 'roman',
                                      -size => 14));
    $self->xl_font($self->fontCreate(-family => 'times',
                                     -slant => 'roman',
                                     -size => 24));
    $self->xxl_font($self->fontCreate(-family => 'times',
                                      -slant => 'roman',
                                      -size => 36));
    
    $self->basic_bg('gray');
    $self->panel_bg('DarkOliveGreen3');
    $self->button_bg('skyblue1');
    $self->active_bg('goldenrod1');
    $self->label_color('whitesmoke');
 
    $self->bg_color($style eq 'panel' ? $self->panel_bg : $self->basic_bg);
    $self->font($self->big_font);
    $self->heading_font($self->xl_font);
    $self->window_style('default') unless $style;
    1;
}

sub stylize{
    my $self = shift;
    my $object = shift;
    my ($style_type, %additional);
    if(@_ == 1){
        $style_type = shift;
    }
    elsif(@_ > 1){
        %additional = @_;
        $style_type = delete $additional{style};
    }
    
    my %possible;    
    $style_type = $self->window_style unless $style_type;


    #--- see if it's a button
    if(ref $object eq 'Tk::Button'){
        $possible{-background} = $self->button_bg;
        $possible{-activebackground} = $self->active_bg;
        $possible{-font}  = $self->big_font;
    }
    else{
        $possible{-background} = ($style_type eq 'panel' ? $self->panel_bg : $self->bg_color);
        if ($style_type eq 'panel' && ref $object eq 'Tk::Frame'){
            $possible{-relief} = 'raised';
            $possible{-borderwidth} = 2;
        }

        if(ref $object eq 'Tk::Label' || ref $object eq 'Tk::Entry' || ref $object eq 'Tk::HList' || ref $object eq 'Tk::Text'){
            $possible{-font} = ($style_type eq 'heading' ? $self->heading_font : $self->font);
        }
    }
    
    if(%additional){
        foreach (keys %additional){
            $possible{$_} = $additional{$_};
        }
    }
    
    $object->configure(%possible);
    
    1;
}


sub new{
    my $class = shift;
    my %p = @_;

    my $self = $p{prior_window}->Toplevel();
    bless $self, $class;
    $self->set_default_profile($p{window_style});

    $self->{frame} = [];
    $self->{unpacked_frames} = [];
    foreach (keys %p){
        $self->$_($p{$_});
    }

    $self->stylize($self);
    return unless $self->init();
    return $self;
}

sub init{1} #--- for subclasses

sub add_text{
    my $self = shift;
    my $text = shift;
    my $style = shift;

    my $widget;
    
    if ( $text =~ /\n/ ?  length($text) > 50 : length($text) > 30){
        $widget = $self->ROText(-wrap => 'word', 
                                -width => 50,
                                -height => 8,
                                -font => $self->medium_font);
        $widget->Insert($text);
    }
    else{
        $widget = $self->Label(-text => $text);
    }
    $self->stylize($widget, $style);
    
    push @{$self->{unpacked_frame}}, $widget;
    
    return $widget;
}


sub new_frame{
    my $self = shift;
    my $frame_type = shift;

    my $frame = $self->Frame();
    $self->stylize($frame => 'style' => ($frame_type ? $frame_type : $self->window_style));
    push @{$self->{frame}}, $frame;
    push @{$self->{unpacked_frame}}, $frame;
    return $frame;
}

sub current_frame{
    my $self = shift;
    unless(@{$self->{frame}}){
        $self->new_frame();
    }
    return $self->{frame}[$#{$self->{frame}}];
}

sub build_gui{
    my $self = shift;
    return 1 if $self->{_gui_is_built};

    if($self->title){
        $self->title($self->title);
    }
    
    if($self->heading){
        my $label = $self->Label(-text => $self->heading, -fg => 'DarkRed')->pack(-side => 'top');
        $self->stylize($label => style => 'heading');
    }
    
    if($self->fullscreen()){
        $self->overrideredirect(1);
    }
    elsif($self->geometry){
        $self->geometry($self->geometry());
    }
    else{
        $self->geometry('640x450+0+0');
    }

    $self->pack_unpacked_frames();
    $self->{_gui_is_built} =1;
    1;
}

sub pack_unpacked_frames{
    my $self = shift;

    foreach (@{$self->{unpacked_frame}}){
        if(ref $_ eq 'Tk::Frame'){
            $_->pack(-side => 'top', -fill => 'x');
        }
        else{
            $_->pack(-side => 'top');
        }
    }
    $self->{unpacked_frame} = [];
    1;
}

sub raise_session{
    my $self = shift;

    $self->build_gui();

    $self->pack_unpacked_frames();

    $self->transient($self->prior_window) if $self->prior_window;
    return $self;
}


sub block{
    my $self = shift;
    $self->raise_session();
    $self->waitWindow($self->prior_window) if $self->prior_window;
    1;
}

sub run{
    my $self = shift;
    $self->raise_session();
    $self->barcode_control(1);
    $::TouchMgr->AddScreen(sub {$self->execute(@_);} );
    1;
}

sub destroy{
    my $self = shift;
    if($self->barcode_control){
        $::TouchMgr->PreviousScreen;
    }
    $self->SUPER::destroy;
    1;
}

sub execute{
    my $self = shift;
    
    if($self->callback){
        my $sub = $self->callback();
        return unless &$sub(@_);
    }
    
    1;
}

1;
