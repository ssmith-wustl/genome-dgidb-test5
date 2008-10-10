package Genome::Model::Command::Build::MetaGenomicComposition::Assemble::PhredPhrap;

use strict;
use warnings;

use Genome;

use Data::Dumper;
#require File::Copy;
#require File::Temp;
require Genome::Consed::Directory;
require Genome::Model::Command;
require Genome::Model::Tools::PhredPhrap::ScfFile;
require IO::Dir;
require IO::File;
#require NCBI::TraceArchive;
use POSIX 'floor';

class Genome::Model::Command::Build::MetaGenomicComposition::Assemble::PhredPhrap {
    is => 'Genome::Model::Command',
    #has =>[
    #],
};

sub help_brief {
    return '(Single Template Projects) Phraps sets of reads from a single template';
}

sub help_detail {
    return '';
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);

    unless ( $self->model ) {
        $self->error_message( sprintf('Can\'t get model for id (%s)', $self->model_id) );
        $self->delete;
        return;
    }

    return $self;
}

sub DESTROY { 
    my $self = shift;

    $self->close_output_fhs;
    $self->SUPER::DESTROY;

    return 1;
}

sub execute {
    my $self = shift;

    my $method = sprintf('_determine_templates_in_chromat_dir_%s', $self->model->sequencing_center);
    my $templates = $self->$method;
    unless ( $templates and %$templates ) {
        $self->error_message(
            sprintf('No templates found in chromat_dir of model (%s)', $self->model->name) 
        );
        return;
    }

    $self->status_message( 
        printf("<=== Running %d assemblies for model (%s) ===>", scalar(keys %$templates), $self->model->name)
    );

    $self->_open_output_fhs
        or return;

    while ( my ($template, $scfs) = each %$templates ) {
        $self->status_message("<=== Assembling $template ===>");
        my $scf_file = sprintf('%s/%s.scfs', $self->model->consed_directory->edit_dir, $template);
        unlink $scf_file if -e $scf_file;
        my $scf_fh = IO::File->new("> $scf_file")
            or ($self->error_message("Can't open file ($scf_file) for writing: $!") and return);
        for my $scf ( @$scfs ) { 
            $scf_fh->print("$scf\n");
        }
        $scf_fh->close;

        unless ( -s $scf_file ) {
            $self->error_message("Error creating SCF file ($scf_file)");
            return;
        }

        my $command = Genome::Model::Tools::PhredPhrap::ScfFile->create(
            directory => $self->model->data_directory,
            assembly_name => $template,
            scf_file => $scf_file,
        );

        #eval{ # if this fatals, we still want to go on
            $command->execute;
            #};
        #FIXME cleanup of auxillary files used to create assembly - .scfs .phds .fasta etc?
        #FIXME create file of oriented fastas? if so remove the assemblies too?

        $self->_add_assembly_fasta_and_qual($template)
            or return;
        $self->_add_scf_fasta_and_qual($template);
        # or return; 
        last;
    }

    $self->_close_output_fhs;

    return 1;
}

sub _open_chromat_dir {
    my $self = shift;

    my $dh = IO::Dir->new( $self->model->consed_directory->chromat_dir );

    return $dh if $dh;

    $self->error_message(
        sprintf('Can\'t open directory (%s): %s', $self->model->consed_directory->chromat_dir, $!)
    );
    return;
}

sub _determine_templates_in_chromat_dir_gsc {
    my $self = shift;

    my $dh = $self->_open_chromat_dir
        or return;

    my %templates;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz##;
        $scf =~ /^(.+)\.[bg]\d+$/
            or next;
        push @{$templates{$1}}, $scf;
    }
    $dh->close;

    return \%templates;
}

sub _determine_templates_in_chromat_dir_broad {
    my $self = shift;

    my $dh = $self->_open_chromat_dir
        or return;

    my %templates;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz$##;
        my $template = $scf;
        $template =~ s#\.T\d+$##;
        $template =~ s#[FR](\w\d\d?)$#\_$1#; # or next;
        
        push @{$templates{$template}}, $scf;
    }
    
    return  \%templates;
}

sub _open_output_fhs {
    my $self = shift;

    for my $seq (qw/ assembly scf /) {
        my $fasta_file = sprintf(
            '%s/%s.%s.fasta',
            $self->model->consed_directory->directory,
            $self->model->subject_name,
            $seq,
        );
        unlink $fasta_file if -e $fasta_file;
        my $fasta_fh = IO::File->new($fasta_file, 'w');
        unless ( $fasta_fh ) {
            $self->error_message("Can't open file ($fasta_file): $!");
            return;
        }
        $self->{ sprintf('_%s_fasta_fh', $seq) } = $fasta_fh;

        my $qual_file = sprintf(
            '%s/%s.%s.fasta.qual',
            $self->model->consed_directory->directory, 
            $self->model->subject_name,
            $seq,
        );
        unlink $qual_file if -e $qual_file;
        my $qual_fh = IO::File->new($qual_file, 'w');
        unless ( $qual_fh ) {
            $self->error_message("Can't open file ($qual_file): $!");
            return;
        }
        $self->{ sprintf('_%s_qual_fh', $seq) } = $qual_fh;
    }

    return 1;
}

sub _close_output_fhs {
    my $self = shift;

    for my $seq (qw/ assembly scf /) {
        $self->{ sprintf('_%s_fasta_fh', $seq) }->close if $self->{ sprintf('_%s_fasta_fh', $seq) };
        $self->{ sprintf('_%s_qual_fh', $seq) }->close if $self->{ sprintf('_%s_qual_fh', $seq) };
    }

    return 1;
}

sub _add_assembly_fasta_and_qual {
    my ($self, $template) = @_;

    # FASTA
    my $ctgs_fasta_file = sprintf('%s/%s.fasta.contigs', $self->model->consed_directory->edit_dir, $template);
    unless ( -s $ctgs_fasta_file ) {
        $self->status_message("Template ($template) did not assemble");
        return 1;
    }

    my $header = $self->_get_header_for_assembly_fasta_and_qual($template)
        or return;
    
    my $ctgs_fasta_fh = IO::File->new("< $ctgs_fasta_file")
        or $self->fatal_msg("Can't open file ($ctgs_fasta_file) for reading");
    my $header_cnt = 0;
    FASTA: while ( my $line = $ctgs_fasta_fh->getline ) {
        if ( $line =~ /(Contig\d+)/ ) {
            last FASTA if ++$header_cnt > 1; # skip other contigs
            #$line = ">$template\n";
            $line = $header;
        }
        $self->{_assembly_fasta_fh}->print($line);
    }
    $self->{_assembly_fasta_fh}->print("\n");

    #QUAL
    my $ctgs_qual_file = sprintf('%s.qual', $ctgs_fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for project (%s)', $ctgs_qual_file, $self->_project->name)
    ) unless -e $ctgs_qual_file;
    my $ctgs_qual_fh = IO::File->new("< $ctgs_qual_file")
        or $self->fatal_msg("Can't open file ($ctgs_qual_file) for reading");
    $header_cnt = 0;
    QUAL: while ( my $line = $ctgs_qual_fh->getline ) {
        if ( $line =~ /(Contig\d+)/ ) {
            last QUAL if ++$header_cnt > 1; # skip other contigs
            #$line = ">$template\n";
            $line = $header;
        }
        $self->{_assembly_qual_fh}->print($line);
    }
    $self->{_assembly_qual_fh}->print("\n");

    return 1;
}

sub _add_scf_fasta_and_qual {
    my ($self, $template) = @_;

    # FASTA
    my $scf_fasta_file = sprintf('%s/%s.fasta', $self->model->consed_directory->edit_dir, $template);
    return 1 unless -s $scf_fasta_file;
    my $scf_fasta_fh = IO::File->new("< $scf_fasta_file")
        or $self->fatal_msg("Can't open file ($scf_fasta_file) for reading");
    while ( my $line = $scf_fasta_fh->getline ) {
        if ( $line =~ /(Contig\d+)/ ) {
            #$line = $header;
        }
        $self->{_scf_fasta_fh}->print($line);
    }
    $self->{_scf_fasta_fh}->print("\n");

    #QUAL
    my $scf_qual_file = sprintf('%s.qual', $scf_fasta_file);
    $self->fatal_msg(
        sprintf('No contigs qual file (%s) for project (%s)', $scf_qual_file, $self->_project->name)
    ) unless -e $scf_qual_file;
    my $scf_qual_fh = IO::File->new("< $scf_qual_file")
        or $self->fatal_msg("Can't open file ($scf_qual_file) for reading");
    while ( my $line = $scf_qual_fh->getline ) {
        if ( $line =~ /(Contig\d+)/ ) {
            #$line = $header;
        }
        $self->{_scf_qual_fh}->print($line);
    }
    $self->{_scf_qual_fh}->print("\n");

    return 1;
}

sub _get_header_for_assembly_fasta_and_qual {
    my ($self, $template) = @_;

    # FIXME
    return $template unless $self->model->name =~ /ocean/i;

    my $ss = ocean_code_to_subscript($template);
    unless ( $ss ) { 
        $self->error_message("Cna't determine subscript code for template ($template)");
        return;
    }
    
    return sprintf(">%s%s\n", $self->model->subject_name, $ss);
}

#-------------------------------------------------------------------------------------------------------------------------
=ocean_code_to_subscript
    extracts plate and well components with regexp
    converts each to decimal value
    appends (rather than adds) well to plate for full value
    sends full value to be converted to subscript
=cut

#globals
our (@HEX) = (0 ..9, 'A' .. 'F');
our (@MYRIAD) = (0 .. 9, 'a' .. 'z', 'A' .. 'Z');

our ($WELL_BASE) = 13;
our @ALPHA = ('a' .. 'h');

our ($PLATE_BASE) = (104);
our ($HEX) = 0xaaa;

sub ocean_code_to_subscript {
    my ($oc) = @_;

    my ($ss) = '';

    #expect format 'aaa01a01'
    if ($oc=~/(\w{3}\d{2})(\w\d{2})/) {
        #get decimal values of components
        my ($plate,$well) = (convert_plate_to_decimal($1), convert_well_to_decimal($2));

        #adjust well
        my ($raw) = $plate * $PLATE_BASE + $well;
        #convert
        $ss = decimal_to_subscript($raw);
    }
    else {
        __PACKAGE__->error_message("improper format for ocean code");
        return;
    }

    return $ss;
}#ocean_code_to_subscript

#-------------------------------------------------------------------------------------------------------------------------
=convert_well_to_decimal
    well value of format \w\d{2}
    use index of \w in @ALPHA to compute decimal value with \d{2}
    ensure numerical portion is less than $WELl_BASE, otherwise can have collisions ex. g13/h00
=cut

sub convert_well_to_decimal {
    my ($well) = @_;

    my ($wtd) = -1;
    my ($CONV, $index) = (scalar(@ALPHA),0);

    if ($well=~/(\w{1})(\d{2})/ and $2 < $WELL_BASE) {
        for ($index = 0; $index < $CONV; $index++) {
            if ($ALPHA[$index] eq $1) { last; }
        }

        #verify ALPHA match
        if ($index < $CONV) {
            $wtd = $index * $WELL_BASE + $2;
        }
        else {
            __PACKAGE__->error_meassge("$well not recognized for well formatting");
            return;
        }
    }
    else {
        __PACKAGE__->error_meassge("$well:improper format ('a00 - h" . ($WELL_BASE - 1) . "')");
        return;
    }   
    
    return $wtd;
}#convert_well_to_decimal

#-------------------------------------------------------------------------------------------------------------------------
=convert_plate_to_decimal
    plate value of format \w{3}\d{2}
    use hex conversion for \w{3} and add to \d{2}
=cut

sub convert_plate_to_decimal()
{
    my ($plate) = @_;
    my ($ptd) = '';

    if ($plate=~/(\w{3})(\d{2})/) {
        $ptd = (hex($1) - $HEX) * $PLATE_BASE + $2;
    }
    else {
        __PACKAGE__->error_meassge("$plate is improper format");
        return;
    }

    return $ptd;
}#convert_plate_to_decimal

#-------------------------------------------------------------------------------------------------------------------------
=decimal_to_subscript
=cut

sub decimal_to_subscript {
    my ($decimal) = @_;
    my ($CONV) = (scalar(@MYRIAD));
    my ($mod, $dts) = (0,'');

    $decimal < 238328 or ( __PACKAGE__->error_meassge("input too large for subscripting") and return );

    while ($decimal > 0) {
        $mod = $decimal % $CONV;
        $dts = $MYRIAD[$mod] . $dts;
        $decimal = floor($decimal/$CONV);
    }

    #pad with leading 0's
    return "0" x (3 - length($dts)) . $dts;
}#decimal_to_subscript

1;

=pod

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
