package Genome::Model::Command::Tools::Reads::Solexa::Bustard;

# This is mostly taken from the old prb2dat.pl script

use strict;
use warnings;

use above "Genome";
use Command;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [ 'input_dir' => { type => 'String', doc => q(The directory to look for prb.txt files; default is '.')},
             'output'    => { type => 'String', doc => q(The directory to write outfiles in; default is ',')},
             'max_read_length' => {type => 'Integer', doc => q(The max read length, used as the 3rd arg to prb2dat_c; default is 50)},
           ],
);

sub help_brief {
    "add reads to a genome model"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
Uses the programs prb2dat_c and seq2loc_c to produce .dat .map and ltxy.dat files from prb files
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

    # Setup the defaults
    my $input_dir = $self->input_dir() || '.';
    my $output = $self->output() || './';
    my $max_read_length = $self->max_read_length() || 50;

    my $prb2dat_c = '/gscmnt/sata114/info/medseq/aml/bin/prb2dat_c';
    unless (-x $prb2dat_c) {
        $self->error_message("$prb2dat_c does not exist or is not executable");
        return;
    }
    my $seq2loc_c = '/gscmnt/sata114/info/medseq/aml/bin/seq2loc_c';
    unless (-x $seq2loc_c) {
        $self->error_message("$seq2loc_c does not exist or is not executable");
        return;
    }

    $input_dir =~ s/\/$//;
    
    my @prb_files = grep { File::Basename::basename($_) } glob("$input_dir/*_prb.txt");
    unless (@prb_files) {
        $self->error_message("No _prb.txt files found in $input_dir");
        return;
    }
    $self->status_message(" found " . scalar(@prb_files) . " prb files");
    
    my $read_length;
    my $read_number = 0;

    my $output_dat_file_name = $output . ".dat";
    my $output_hdr_file_name = $output . ".dat.hdr";
    my $output_map_file_name = $output . ".map";
    my $output_ltxy_file_name = $output . "_ltxy.dat";

    if (-e $output_dat_file_name) {
        die "Appending to an existing output file $output_dat_file_name is currently not supported.  Fixme.\n";
    }   
      
    if (-e $output_hdr_file_name) {
        die "Appending to an existing output file $output_hdr_file_name is currently not supported.  Fixme.\n";
    }   
      
    if (-e $output_map_file_name) {
        $self->error_message("Map file $output_map_file_name already exists!?");
        return;
    }

    my $output_map_fh = IO::File->new('>' . $output_map_file_name);
    unless ($output_map_fh) {
        $self->error_message("Failed to open $output_map_file_name for writing: $!");
        return;
    }
    $output_map_fh->autoflush(1);
      
    $self->status_message(" writing file of read base qualities to $output_dat_file_name");
      
    my $output_hdr_fh = IO::File->new('>' . $output_hdr_file_name);
    unless ($output_hdr_fh) {
        $self->error_message("Failed to open $output_hdr_file_name for writing: $!");
        return;
    }

    for my $prb_file_name (sort @prb_files) {

        my ($lane,$tile) = ($prb_file_name =~ /s_(.*?)_(.*?)_prb.txt/);
    
        $self->status_message(" processing $prb_file_name: lane $lane, tile $tile.  Offset is $read_number reads");
        $output_map_fh->print("$lane\t$tile\t$read_number\n");
        
        my $prb_fh = IO::File->new($prb_file_name);
        unless ($prb_fh) {
            $self->error_message("Failed to open $prb_file_name for reading: $!");
            return;
        }
    
        my $reads = IO::File->new("$prb2dat_c $prb_file_name $output_dat_file_name $max_read_length |");
        unless ($reads) {
            $self->error_message("Failed to run $prb2dat_c: $!");
            return;
        }
        my $return_value = <$reads>;
        close($reads);

        my $read_number_in_file;
        if ($return_value =~ /^ \s* (\d+) \s+ (\d+) \s* $/x) {
            ($read_number_in_file,$read_length) = ($1,$2);    # FIXME this gets changed each time through the loop, but only written once at the end!?
        } else {
            $self->error_message("$return_value converting file: $prb_file_name");
            return;
        }

        $read_number += $read_number_in_file;
        my $seq_file_name = $prb_file_name;
        $seq_file_name =~ s/_prb/_seq/;
        system("$seq2loc_c $seq_file_name $output_ltxy_file_name");
    }

    if (defined($output_hdr_fh)) {
        $output_hdr_fh->print("# PDL::IO::FlexRaw header\n");
        $output_hdr_fh->print("byte 3 4 $read_length $read_number\n");
        $output_hdr_fh->close();
    }

    return 1;
}

1;


