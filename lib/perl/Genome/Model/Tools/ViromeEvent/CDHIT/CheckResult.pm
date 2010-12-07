
package Genome::Model::Tools::ViromeEvent::CDHIT::CheckResult;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;
use File::Basename;

class Genome::Model::Tools::ViromeEvent::CDHIT::CheckResult{
    is => 'Genome::Model::Tools::ViromeEvent',
};

sub help_brief {
    "gzhao's cdhit check_result script for virome"
}

sub help_synopsis {
    return <<"EOS"
 check the result of cdhit to make sure it finished
EOS
}

sub help_detail {
    return <<"EOS"

 check the result of cdhit to make sure it finished

EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;

}

sub execute {
    my $self = shift;
    my $dir = $self->dir;
    my $sample_name = basename ($dir);

    #$self->log_event("cdhit checkresult entered for $sample_name");

    my $faFile = $dir.'/'.$sample_name.'.fa';
    my $cdhitReport = $faFile.'.cdhitReport';

    if (-s $cdhitReport) {
        my $result = `grep completed $cdhitReport`;
        if ($result =~ /program completed/) {
	    $self->log_event("Already completed for sample: $sample_name");
	    return 1;
        }
    }

    #RUN CD-HIT
    #DETERMINE WHETHER TO RUN 32 OR 64 BIT VERSIONS OF CD-HIT

    my $archos = `uname -a`;
    my $cd_hit_dir = ($archos =~ /64/) ? '/cd-hit-64/cd-hit-est' : '/cd-hit-32/cd-hit-est';    

    my $com = '/gsc/var/tmp/virome/scripts'.$cd_hit_dir .
	      ' -i ' . $faFile .
	      ' -o ' . $faFile . '.cdhit_out' .
	      ' -c 0.98 -n 8 -G 0 -aS 0.98 -g 1 -r 1 -M 4000 -d 0' .
	      ' > ' . $cdhitReport;

    $self->log_event("Executing for sample: $sample_name");

    if (system($com)) { #RETURNS 0 WHEN SUCCESSFUL
        $self->log_event("Failed for sample: $sample_name");
        return;
    }
    else {
        $self->log_event("Ran successfully for sample: $sample_name");
        return 1;
    }
}

1;

sub sub_command_sort_position { 7 }
