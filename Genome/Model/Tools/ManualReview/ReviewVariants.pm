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
        project_directory => 
        {
            type => 'String',
            is_optional => 1,
            doc => "File of input maps",
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
    my $project_dir = $self->project_directory;
    
    $DB::single = 1;
    
    my $glade = new Gtk2::GladeXML("/gscuser/jschindl/svn/dev/perl_modules/Genome/manual_review/manual_review.glade","manual_review");
    my $mr = Genome::Model::Tools::ManualReview::MRGui->new(g_handle => $glade);

    $glade->signal_autoconnect_from_package($mr);

    my $mainWin = $glade->get_widget("manual_review");
    my $treeview = $glade->get_widget("review_list");
    $mr->build_review_tree;

    $mainWin->signal_connect("destroy", sub { Gtk2->main_quit });
    $mr->open_file("/gscuser/jschindl/svn/dev/perl_modules/out/test.csv");
    Gtk2->main();
    return 1;
}
############################################################
1;
