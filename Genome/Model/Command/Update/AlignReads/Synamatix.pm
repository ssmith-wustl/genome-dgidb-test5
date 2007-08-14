
package Genome::Model::Command::Update::AlignReads::Synamatix;

use strict;
use warnings;

use UR;
use Command;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => ['run_number','lane_number','refseq', 'minimum_score'],
);

sub help_brief {
    "launch the aligner for a given set of new reads"
}

sub help_detail {                       
    return <<EOS 


EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {
    my $self = shift;
    my $min_score = (defined $self->minimum_score ? $self->minimum_score : 20);

    my $info = Genome::Model::get_runs_info();

    if (!defined $self->run_number || !exists $info->{$self->run_number}) {
	$self->error_message("Run number not provided or is invalid");
	return 0;
    }

    if (!defined $self->lane_number) {
	$self->error_message("Lane number not provided");
	return 0;
    }

    if (!defined $self->refseq) {
	$self->error_message("refseq db not provided");
	return 0;
    }

    my $refseq = $self->refseq;

    my $bp = $info->{$self->run_number}->{bustard_path};

    my @c = glob(printf("$bp/s_%n_*_prb.txt",$self->lane_number));

    my $output_dir = $self->derive_output_path($self->run_number);

    foreach my $tile_filename (@c) {
        my $prb_name = File::Basename::basename($tile_filename);
        my $sxog_out_name = $output_dir . "/" . $prb_name . ".sxog";
        
        my $p = PP->create(pp_type=>'LSF',
                           q=>'ia64',
                           e=>"$output_dir/errors_$prb_name",
                           select=>['synamatix'],
                           function=>sub{
                               my $sxog_cmd = "SXbash SXOligoSearchG -l -x $min_score -p 0.015 -s 28 -r 999 $refseq $tile_filename > $sxog_out_name; bzip2 $sxog_out_name";
                               system($sxog_cmd);
                           });
        $p->start;
    }


    return 1;
}

sub derive_output_path {
    my ($self, %params) = @_;
    
    my $info = Genome::Model::get_runs_info();
    
    if (!defined $params{run_number} || 
        !exists $info->{$params{run_number}}) {
        $self->error_message("Run number not provided or is invalid");
        return;
    }
    
    my $rn = $params{run_number};
    
    my $sp = $info->{run_number};
    
    my $fullpath = $sp . "/runs/solexa/aml$rn/sxog_out";
    return $fullpath;
}

1;



