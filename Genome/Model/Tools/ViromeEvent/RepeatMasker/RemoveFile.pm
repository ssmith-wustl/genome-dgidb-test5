
package Genome::Model::Tools::ViromeEvent::RepeatMasker::RemoveFile;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::ViromeEvent::RepeatMasker::RemoveFile{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    return "gzhao's Repeat Masker remove files";
}

sub help_synopsis {
    return <<"EOS"
This script will check the result of RepeatMasker which
should generate .masked file in the given directory.

perl script <dir>
<dir> = full path to the directory of a sample library
               without last "/"
EOS
}

sub help_detail {
    return <<"EOS"
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute
{
    my $self = shift;
    my $dir = $self->dir;

    $self->log_event("Repeat Masker remove file entered for $dir");

    my $allFinished = 1;
    opendir(DH, $dir) or die "Can not open dir $dir!\n";
    foreach my $name (readdir DH) {
        if ($name =~ /.cdhit_out_RepeatMasker$/) { # RepeatMasker directory
	    my $full_path = $dir."/".$name;
        	opendir(SubDH, $full_path) or die "can not open dir $full_path!\n";
	        foreach my $file (readdir SubDH) {
        	    if ($file =~ /\.cdhit_out_file\d+\.fa$/) {
	        	my $have_masked = 0;
		        my $have_other = 0;
		
        		my $tempfile = $full_path."/".$file.".tbl";
        		if (-e $tempfile) {unlink $tempfile};
    		
        		$tempfile = $full_path."/".$file.".cat";
        		if (-e $tempfile) {unlink $tempfile};
		
        		$tempfile = $full_path."/".$file.".out";
        		if (-e $tempfile) {
        		    unlink $tempfile;
	        	};
        	    }
        	}
            }
    }

    $self->log_event("Repeat Masker remove file completed");

    return 1;
}


1;

