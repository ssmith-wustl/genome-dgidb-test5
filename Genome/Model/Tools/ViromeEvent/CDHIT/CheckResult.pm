
package Genome::Model::Tools::ViromeEvent::CDHIT::CheckResult;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

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

sub execute
{
    my $self = shift;
    my $dir = $self->dir;

    $self->log_event("cdhit checkresult entered for $dir");

    my $have_out = 0;
    my $finished = 0;

    use File::Basename;
    my $base_name = basename ($dir);
    my $faFile = $dir.'/'.$base_name.'.fa';
    my $cdhitReport = $faFile.'.cdhitReport';

    if (-s $cdhitReport) 
    { 
        $have_out = 1;
        my $result = `grep completed $cdhitReport`;
        if ($result =~ /program completed/) 
        {
	    $finished = 1;
        }
    }

    if ($have_out && $finished) 
    {
	$self->log_event("CDHIT already run");
        return 0;
    }
    else 
    {
        # rerun cdhit

        #DETERMINE WHETHER TO RUN 32 OR 64 BIT VERSIONS OF CD-HIT
        my $cd_hit_dir = '/cd-hit-32/cd-hit-est';

        my $archos = `uname -a`;
        if ($archos =~ /64/) 
        {
	    $cd_hit_dir = '/cd-hit-64/cd-hit-est';
        }

        my $str = $faFile;

        my $com = '/gsc/var/tmp/virome/scripts'.$cd_hit_dir.' -i '.$str.' -o '.$str.'.cdhit_out -c 0.98 -n 8 -G 0 -aS 0.98 -g 1 -r 1 -M 4000 -d 0'.' > '.$cdhitReport;

        $self->log_event("CDHIT calling command: $com");

        my $ec = system($com);
        if ($ec) 
        {
	    $self->log_event("CDHIT Failed: re-run of cd-hit for $str");
	    #cd-hit-est is a c++ code, return 0 when successful
	    die("CDHIT Failed: re-run of cd-hit for $str");
        }
        else 
        {
	    $self->log_event("CDHIT check result Succeeded: re-run of cd-hit for $str");
	    return 0;
        }
    }
    $self->log_event("cdhit check result completed");
}

1;

sub sub_command_sort_position { 7 }
