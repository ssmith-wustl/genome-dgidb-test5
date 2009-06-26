package Genome::Model::Tools::Sv::Peruse;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Sv::Peruse {
    is => 'Command',
    has => [
    breakdancer_file => 
    { 
        type => 'String',
        is_optional => 0,
        doc => "Input file of breakdancer output for a single individual",
    },
    dir =>
    {
        type => 'String',
        is_optional => 0,
        doc => "directory produced by gt sv yenta",
    },        
    viewer_program => {
        type => "String",
        default => "eog",
        doc => "viewer executable to use", 
        is_optional => 1,
    },
    types => {
        type => 'String',
        is_optional => 1,
        doc => "Comma separated string of types to pop up",
        default => "INV,INS,DEL,ITX,CTX",
    },
    possible_BD_type => {
        type => 'hashref',
        doc => "hashref of possible BreakDancer SV types",
        is_optional => 1,
        default => {INV => 1,INS => 1,DEL => 1,ITX => 1,CTX => 1,},
    },

    ],
};


sub execute {
    my $self=shift;
    $DB::single = 1; 
    
    my @types = map { uc $_ } split /,/, $self->types;
    my $allowed_types = $self->possible_BD_type;
    foreach my $type (@types) {
        unless(exists($allowed_types->{$type})) {
            $self->error_message("$type type is not a valid BreakDancer SV type");
            return;
        }
    }
    my %types = map {$_ => 1} @types; #create types hash

    unless(-f $self->breakdancer_file) {
        $self->error_message("breakdancer file is not a file: " . $self->breakdancer_file);
        return;
    }

    my $indel_fh = IO::File->new($self->breakdancer_file);
    unless($indel_fh) {
        $self->error_message("Failed to open filehandle for: " .  $self->breakdancer_file );
        return;
    }

    my $dir = $self->dir;

    my $viewer = $self->viewer_program;
    
    #assuming we are reasonably sorted
    while ( my $line = $indel_fh->getline) {
        chomp $line;
        #$self->status_message("(SEARCHING FOR: $line)");
        my ($chr1,
            $chr1_pos,
            $orientation1,
            $chr2,
            $chr2_pos,
            $orientation2,
            $type,
            $size,
        ) = split /\s+/, $line; 
        if(exists($types{$type})) {
            #then we should graph it
            #submit the job
            #Doing this based on chromosomes in case types ever change
            my $name = "$dir/${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_*_${type}*.png";
            print "Opening files for ${chr1}_${chr1_pos}_${chr2}_${chr2_pos}_${type}\n";
            system("$viewer $name &");
            my $next = <STDIN>;
            chomp $next;
            if($next eq 'q') {
                last;
            }

        }
            
    }

    $indel_fh->close; 

    return 1;
}

1;

sub help_detail {
    my $value = <<HELP;
This module reads through a breakdancer output file and opens up all the associated files produced through gt sv yenta for viewing. The default viewer is eog. Each viewer is opened as a background process. To proceed to the next SV just hit enter. To quit, type q.
HELP
    
    return $value;
}

sub help_brief {
    return "View directory of yenta graphs";
}


