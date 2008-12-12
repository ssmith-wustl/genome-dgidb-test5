package Genome::Model::Tools::ManualReview::ReviewVariants;
use strict;
use warnings;
use Genome::Model::Tools::ManualReview::MRGui;
use Command;
use Data::Dumper;
use IO::File;
use PP::LSF;
use File::Temp;
use File::Basename;
class Genome::Model::Tools::ManualReview::ReviewVariants
{
    is => 'Command',                       
    has => 
    [ 
        project_file => 
        {
            type => 'String',
            is_optional => 1,
            doc => "Manual review csv file",
        },

    ], 
};
############################################################
sub help_brief {   
    return;
}
sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    Launches the variant review editing application.
EOS
}
############################################################
sub execute { 
    my $self = shift;
    my $project_file = $self->project_file;
    
    $DB::single = 1;
    my $mr_dir = 'Genome/Model/Tools/ManualReview';
    foreach my $path (@INC) {
        my $fullpath = $path . "/" .$mr_dir;
        if( -e $fullpath) {
            $mr_dir = $fullpath;
            last;
        }
    }
    
    chomp $mr_dir;
    
    $mr_dir .= '/manual_review.glade';
    
    my $glade = new Gtk2::GladeXML($mr_dir,"manual_review");
    my $mr = Genome::Model::Tools::ManualReview::MRGui->new(g_handle => $glade);

    $glade->signal_autoconnect_from_package($mr);

    my $mainWin = $glade->get_widget("manual_review");
    my $treeview = $glade->get_widget("review_list");
    $mr->build_review_tree;

    $mainWin->signal_connect("destroy", sub { Gtk2->main_quit; system "killall consed"; });
    $mr->open_file($project_file) if($project_file && -e $project_file);

    Gtk2->main();
    return 1;
}
############################################################
1;
