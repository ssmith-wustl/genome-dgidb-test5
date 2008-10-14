package Genome::Model::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

use Genome::Consed::Directory;
use Genome::ProcessingProfile::MetaGenomicComposition;
use POSIX 'floor';

class Genome::Model::MetaGenomicComposition {
    is => 'Genome::Model',
    has => [
    map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::MetaGenomicComposition->params_for_class
    ),
    ],
};

#< Dirs, Files >#
sub consed_directory { #TODO put this on class def
    my $self = shift;

    return $self->{_consed_dir} if $self->{_consed_dir};
    
    $self->{_consed_dir} = Genome::Consed::Directory->create(directory => $self->data_directory);
    $self->{_consed_dir}->create_consed_directory_structure; # TODO put in create

    return $self->{_consed_dir};
}

sub _fasta_file_name {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s.%s.fasta',
        $self->consed_directory->directory,
        $self->subject_name,
        $type,
    );
}

sub all_assembly_fasta {
    return _fasta_file_name(@_, 'assembly');
}

sub all_scf_fasta {
    return _fasta_file_name(@_, 'scf');
}

#< Determining subclones >#
sub subclones_and_traces_for_assembly {
    my $self = shift;

    my $method = sprintf('_determine_subclones_in_chromat_dir_%s', $self->sequencing_center);
    my $subclones = $self->$method;
    unless ( $subclones and %$subclones ) {
        $self->error_message(
            sprintf('No subclones found in chromat_dir of model (%s)', $self->name) 
        );
        return;
    }

    return $subclones;
}

sub _determine_subclones_in_chromat_dir_gsc {
    my $self = shift;

    my $dh = $self->_open_directory( $self->consed_directory->chromat_dir )
        or return;

    my %subclones;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz##;
        $scf =~ /^(.+)\.[bg]\d+$/
            or next;
        push @{$subclones{$1}}, $scf;
    }
    $dh->close;

    return \%subclones;
}

sub _determine_subclones_in_chromat_dir_broad {
    my $self = shift;

    my $dh = $self->_open_directory( $self->consed_directory->chromat_dir )
        or return;

    my %subclones;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz$##;
        my $subclone = $scf;
        $subclone =~ s#\.T\d+$##;
        $subclone =~ s#[FR](\w\d\d?)$#\_$1#; # or next;
        
        push @{$subclones{$subclone}}, $scf;
    }
    
    return  \%subclones;
}

sub _open_directory {
    my ($self, $dir) = @_;

    my $dh = IO::Dir->new($dir);

    return $dh if $dh;

    $self->error_message("Can't open directory ($dir)");
    
    return;
}

sub assembly_size { # put in proc prof
    my $self = shift;

    # HACK
    my ($rs, $ps) = $self->name =~/^Ocean (1[68])S \d+\w? ([ABC][BCD]) /;
    my %sizes = (
        '16AB' => 1464,
        '16BC' => 876,
        '18AB' => 1640,
        '18CD' => 1465,
    );
    
    return $sizes{"$rs$ps"};
}

sub header_for_subclone {
    my ($self, $subclone) = @_;

    # FIXME
    return ">$subclone\n" unless $self->name =~ /ocean/i;

    my $ss = ocean_code_to_subscript($subclone);
    unless ( $ss ) { 
        $self->error_message("Cna't determine subscript code for subclone ($subclone)");
        return;
    }
    
    return sprintf(">%s%s\n", $self->subject_name, $ss);
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


# Not sure what dese are...
sub _test {
    # Hard coded param for now
    return 1;
}

sub _build_subclass_name {
    return 'assembly';
}

sub _assembly_directory {
    my $self = shift;
    return $self->data_directory . '/assembly';
}


1;

=pod
=cut

#$HeadURL$
#$Id$
