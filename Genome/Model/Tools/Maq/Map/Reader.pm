package Genome::Model::Tools::Maq::Map::Reader;

use strict;
use warnings;
use Class::ISA;
use Carp;
            
our $libs;
BEGIN
{
    $libs = '-L/var/chroot/etch-ia32/usr/lib -L/usr/lib -L/lib ';        
};

use Genome::InlineConfig;
use Inline 'C' => 'Config' => (
            CC => '/gscmnt/936/info/jschindl/gcc32/gcc',
            DIRECTORY => Genome::InlineConfig::DIRECTORY(), 
            INC => '-I/gscmnt/936/info/jschindl/inline_c_deps -I/gsc/pkg/bio/maq/zlib/include',
            CCFLAGS => '-D_FILE_OFFSET_BITS=64 -m32 ',
            LD => '/gscmnt/936/info/jschindl/gcc32/ld',
            LIBS => '-L/gscmnt/936/info/jschindl/inline_c_deps -L/gsc/pkg/bio/maq/zlib/lib -lz -lmaq '.$libs,
            NAME => __PACKAGE__
            );

sub new {
    Carp::croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = \%params;
    
    bless ($self, $class);
    
    $self->open($self->{file_name}) if($self->{file_name});
    return $self;
}

sub open
{
    my ($self, $file_name) = @_;
    $self->close() if defined $self->{input_file};
    $self->{input_file} = init_file($file_name);
    $self->{header} = $self->init_header;
}

sub close
{
    my ($self) = @_;
    close_file($self->{input_file});
    $self->{input_file} = undef;
    $self->{header} = undef;
}

sub do
{

    my ($self, $func_name_or_ref,$package) = @_;
    
    ($self->{calling_package}) = caller;
    my ($func_type, $func_ref) = $self->resolve_func_type($func_name_or_ref,$package);
    if($func_type eq 'perl_func')
    {
        do_with_perl_func($self->{input_file}, $func_ref);
    }
    elsif($func_type eq 'c_func')
    {
        do_with_c_func($self->{input_file}, $func_ref);
    }
}

sub get_next
{
    my ($self) = @_;
    return get_next_perl_record($self->{input_file});
    
}

sub reset
{
    my ($self) = @_;
    _reset($self->{input_file});
    return 1;
}

sub resolve_func_type
{
    my ($self, $func_name_or_ref, $package) = @_; #print join ' ',@DynaLoader::dl_modules,"\n";
    return ('','') unless defined $func_name_or_ref;
    #if this is a perl code ref we're done 
    if(ref($func_name_or_ref) eq 'CODE')
    {
       return ('perl_func', $func_name_or_ref);
    }

    my $temp_package;    
    my $func_ref;
    my $func_name;    

    ($temp_package,$func_name) = $func_name_or_ref =~ /(.*)::(.+)/;#user fully qualified function
	$package = $temp_package if(!defined $package && defined $temp_package);#user specified package name
    $func_name = $func_name_or_ref if(!defined $func_name);
    $package = $self->{calling_package} if(!defined $package);#user didn't specify package asume it's in same package as caller
	
    if(defined $package && defined $func_name)
    {
		if($package->isa("DynaLoader"))
		{	
			my @in = Class::ISA::self_and_super_path($package);
			my @dl = @DynaLoader::dl_modules;
			my @dl_modules = grep {  my $string = $_; grep(/^$string$/,@dl); } @in;		
			
			foreach my $dl_package (@dl_modules)
			{
        		my $package_number = dynaloader_has_package($dl_package);        	
        		if(defined $package_number)
        		{
            		$func_ref = DynaLoader::dl_find_symbol($DynaLoader::dl_librefs[$package_number], $func_name);
            		return ('c_func', $func_ref) if(defined $func_ref);    
        		}
        	}
		    				
		}
		no strict 'refs';
		if(exists ${$package.'::'}{$func_name} && defined &{$package.'::'.$func_name})
        {
            #print "found perl func\n";
            $func_ref = \&{$package.'::'.$func_name};
            use strict 'refs';
            return ('perl_func',$func_ref);   
        } 
		use strict 'refs';
    }
    
    
    print "Couldn't resolve type for $func_name_or_ref.\n";
    return ('', '');    
    #dangerous, but we have no way of knowing if a void pointer is valid without trying it,
    #not sure if I like this 'feature'
    #return ('c_func', $func_name_or_ref);
    
}
sub dynaloader_has_package
{
    my ($package_name) = @_;
    return undef if(!defined $package_name);
    for(my $i = 0;$i<@DynaLoader::dl_modules;$i++)
    {
        return $i if($DynaLoader::dl_modules[$i]=~/$package_name/);
    }
    return undef;
}

sub init_header
{
    my ($self) = @_;
    
    return _init_header($self->{input_file});
}

sub read_header
{
    my ($self) = @_;
    if(defined $self->{header})
    {
        return $self->{header};
    }
    else
    {
        die "Header not defined.\n";
    }

}

use Inline C => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))

typedef void (*do_func)(maqmap1_t *mm);
SV *build_perl_header(maqmap_t *mm);

SV *_init_header(void * fpin)
{
    maqmap_t  *mm = maqmap_read_header(fpin);
    SV *perl_header = build_perl_header(mm);
    maq_delete_maqmap(mm);
    return perl_header;
}

void * init_file(char *infile)
{
    gzFile fpin = gzopen(infile, "r");
    //read_header((void *)fpin);
    return (void *)fpin;
}

void _reset(void *fpin)
{
    gzrewind(fpin);
    maqmap_read_header((void *)fpin);
}

void close_file(void * fpin)
{
    gzclose((gzFile)fpin);
}

char * get_read(maqmap1_t *mm)
{
    static char string[MAX_READLEN];
    int j = 0;
    for (j = 0; j < mm->size; ++j) {
        if (mm->seq[j] == 0) string[j] ='n';
        else if ((mm->seq[j]&0x3f) < 27) string[j]="acgt"[mm->seq[j]>>6&3];
        else string[j]="ACGT"[mm->seq[j]>>6&3];
    }
    string[mm->size]=0x00;
    return string;    
}

SV * get_qual(maqmap1_t *mm)
{
    int j =0;
    AV *AV_qual = newAV();
    sv_2mortal((SV *)AV_qual);
    for (j = 0; j < mm->size; ++j)
        av_push(AV_qual, newSViv((mm->seq[j]&0x3f) + 33));
    
    return newRV_inc((SV *)AV_qual);
}

SV * build_perl_hash(maqmap1_t *mm)
{
    HV * rec = newHV();
    sv_2mortal((SV *)rec);
    hv_store(rec, "name",4,newSVpv(mm->name,0),0);//printf("here is the name %s\n",mm->name);
    hv_store(rec, "size",4,newSViv(mm->size),0);
    hv_store(rec, "seq",3,newSVpvn(get_read(mm),mm->size),0);
    hv_store(rec, "pos",3,newSViv(mm->pos),0);
    hv_store(rec, "seqid",5,newSViv(mm->seqid),0);
    hv_store(rec, "qual",4,get_qual(mm),0);
    hv_store(rec, "single_end_map_qual",strlen("single_end_map_qual"),newSViv(mm->seq[MAX_READLEN-1]),0);
    hv_store(rec, "map_qual",8,newSViv(mm->map_qual),0);
    hv_store(rec, "alt_qual",8,newSViv(mm->alt_qual),0);
    hv_store(rec, "flag",4,newSViv(mm->flag),0);
    hv_store(rec, "dist",4,newSViv(mm->dist),0);
    hv_store(rec, "24bp_mismatches",strlen("24bp_mismatches"),newSViv(mm->info1>>4),0);
    hv_store(rec, "mismatches",strlen("mismatches"),newSViv(mm->info1&0x0f),0);
    hv_store(rec, "info2",5,newSViv(mm->info2),0);
    hv_store(rec, "c0",2,newSViv(mm->c[0]),0);
    hv_store(rec, "c1",2,newSViv(mm->c[1]),0);
    return (SV *)newRV_inc((SV *)rec);
}

SV *get_ref_name(char **ref_name, int n_ref)
{
    int i =0;
    AV *AV_ref_name = newAV();
    sv_2mortal((SV *)AV_ref_name);
    for (i = 0; i < n_ref; i++)
        av_push(AV_ref_name, newSVpv(ref_name[i],0));
    
    return newRV_inc((SV *)AV_ref_name);

}

SV *build_perl_header(maqmap_t *mm)
{
    HV * rec = newHV();
    sv_2mortal((SV *)rec);
    char string[256];
    bzero(string,256);
    //printf("n_mapped_reads is %llu\n",mm->n_mapped_reads);
    sprintf(string, "%llu", (unsigned long long)mm->n_mapped_reads);
    //printf("n_mapped_reads string is %s\n",string);
    hv_store(rec, "format",strlen("format"),newSViv(mm->format),0);
    hv_store(rec, "n_ref",strlen("n_ref"),newSViv(mm->n_ref),0);   
    hv_store(rec, "ref_name",strlen("ref_name"),get_ref_name(mm->ref_name,mm->n_ref),0);
    hv_store(rec, "n_mapped_reads",strlen("n_mapped_reads"),newSVpv(string,0),0);
    return (SV *)newRV_inc((SV *)rec);
}


void call_perl_do_func(SV * perl_func, maqmap1_t *mm)
{
    dSP ;

    ENTER ;
    SAVETMPS ;

    PUSHMARK(SP) ;
    XPUSHs(sv_2mortal(build_perl_hash(mm)));//build_perl_hash creates a mortal hash ref
    PUTBACK ;

    call_sv(perl_func, G_DISCARD);

    FREETMPS ;
    LEAVE ;
}

void do_with_perl_func(void * fpin,SV * perl_func) 
{

    maqmap1_t curr_mm;

    while(get_record((gzFile)fpin, &curr_mm))
    { 
        call_perl_do_func(perl_func, &curr_mm); 
    }
}

SV * get_next_perl_record(void * fpin)
{
    static maqmap1_t curr_mm;
    if(get_record((gzFile)fpin,&curr_mm))
        return build_perl_hash(&curr_mm);
    else
        return &PL_sv_undef;
}

void do_with_c_func(void * fpin,void * tempfunc) 
{
    //maqmap_t  *mm = maqmap_read_header((gzFile)fpin);
    do_func func = tempfunc;
    
    static maqmap1_t curr_mm;
    
    while(get_record((gzFile)fpin, &curr_mm))
    {
        (*func)(&curr_mm);
    }
}
END_C
1;
=pod

=head1 NAME

Genome::Model::Tools::Maq::Map::Reader - Map File Reader/Iterator

=head1 SYNOPSIS

my $mi = Genome::Model::Tools::Maq::Map::Reader->new();

 $mi->open("inputfilename");
 my $map_header = $mi->read_header();
 
 while(my $map_record = $mi->get_next)
 {
    print Dumper($map_record);
 
 }
 $mi->close;
 
 --or--
 $mi->open("inputfilename");
 my $map_header = $mi->read_header();
 
 $mi->do('do_func');
 
 $mi->close;
 
 sub do_func
 {
    my ($record) = @_;
    print Dumper($record);
 }
 
 --or--
 use Inline C;
 $mi->open("inputfilename");
 my $map_header = $mi->read_header();
 
 $mi->do('do_func_c');
 
 $mi->close;
 __END__
 __C__
 #include "mapmap.h"
 void do_func_c(maqmap1_t *mm)
 {
     maqmap1_t *temp = (maqmap1_t *)mm;
     printf("%s\n",temp->name);
 }
 
 
    
=head1 DESCRIPTION

Genome::Model::Tools::Maq::Map::Reader is a map file reader/iterator.  It allows the implementation of callbacks
in C for fast iteration over a Map file.

=head1 METHODS

=head1 new 

my $mi = Genome::Model::Tools::Maq::Map::Reader->new;

=head1 open 

$mi->open("input_file_name");

input_file_name - required before reading from map file

=head1 read_header 

my $header = $mi->read_header();
    
returns a hash representing the map file header.

=head1 get_next

my $record = $mi->get_next;
    
returns a hash containing the next record in the map file stream.

=head1 do

 $mi->do('do_func');
 $mi->do($perl_func_ref);
 $mi->do('do_func_c');
 
 Takes either a perl function name, perl function ref, or C function name, and performs that operation for 
 each record in the map file.  The first argument to the perl do_func is a hash containing the map file record.  
 The first argument to the C implementation of a do_func is a pointer to a maqmap1_t record.  

=head1 Author(s)

 Jon Schindler <jschindl@watson.wustl.edu>

=cut
