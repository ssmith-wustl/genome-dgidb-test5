package Genome::Model::Tools::SeeFive::ToPerl;

use strict;
use warnings;

use Genome;            
use Genome::Model::Tools::SeeFive::Trial;
use Genome::Model::Tools::SeeFive::Rule;

class Genome::Model::Tools::SeeFive::ToPerl {
    is => 'Command',
    has => [ 
        input   => { is => 'FileName', default_value => '-', doc => 'c4.5 or c5 rule output' },
        output  => { is => 'FileName', is_optional => 1, doc => 'results file' },
    ],
};

sub sub_command_sort_position { 1 }

sub help_brief {
    'Turn rule output into perl.'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools c5 to-perl
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;    
    return $self;
}

sub execute {
    $DB::single = 1;
    my $self  = shift;
    print $self->input;

    my $fhin = IO::File->new($self->input);
    $fhin or die;

    my $fhout;
    if (my $fhout_name = $self->output) {
        $fhout = IO::File->new('>'.$fhout_name);
    }
    else {
        $fhout = 'STDOUT';
    }
    $fhout or die;

    my @trials;
    my $current_trial;
    my $current_rule;
    my $current_rule_lines;

    while ($_ = $fhin->getline) {
        if (/Trial\s+(\d+)/) {
            $current_trial = Genome::Model::Tools::SeeFive::Trial->create(
                n => $1,
            );
            die unless $current_trial;
            push @trials, $current_trial;
        }
        next unless defined $current_trial;
        next if /^Rules:\s*$/;
        
        if (
            my ($trial,$n,$possible_items,$wrong_items,$lift) 
            = ($_ =~ qr{^Rule (\d+)/(\d+): \((\d+)\/(\d+), lift ([\d\.]+)\)\s*$}) 
        ) {
            $current_rule = Genome::Model::Tools::SeeFive::Rule->create(
                trial_id => $current_trial->id,
                n => $n,
                possible_items => $possible_items,
                wrong_items => $wrong_items,
                lift => $lift,
            );
            $current_rule_lines = [];
            $current_rule->lines($current_rule_lines);
            next;
        }
        next unless defined $current_rule;

        if (/^\s*$/) {
            $current_rule = undef;
        }
        else {
            push @$current_rule_lines, $_;
        }
    }
    
    for my $trial (@trials) {
        print "trial " . $trial->n, "\n";
        print $trial->perl_src;
    }

    return 1;
}

1;

