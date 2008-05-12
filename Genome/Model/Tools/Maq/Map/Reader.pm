#this code is not quite done yet, jschindl - 5/12/2008
package Genome::Model::Tools::Maq::Map::Reader;

our $inline_dir;
BEGIN
{
    ($inline_dir) = "$ENV{HOME}/".(`uname -a ` =~ /ia64 / ? '_Inline64' : '_Inline32');
    mkdir $inline_dir;
};

use Class::ISA;
use Inline (C =>'DATA',
            DIRECTORY => $inline_dir,
            INC => '-I/gscuser/jschindl -I/gscuser/jschindl/svn/gsc/zlib-1.2.3',
            CCFLAGS => '-D_FILE_OFFSET_BITS=64',
            LIBS => '-L/gscuser/jschindl -L/gscuser/jschindl/svn/gsc/zlib-1.2.3 -lz -lmaq',
            NAME => __PACKAGE__
            );
            
sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, $arg, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};#\%params;
    
    bless ($self, $class);
    
    $self->open($self->{file_name}) if($self->{file_name});
    return $self;
}

sub open
{
    my ($self, $file_name) = @_;
    $self->close() if defined $self->{input_file};
    $self->{input_file} = init_file($file_name);
}

sub close
{
    my ($self) = @_;
    close_file($self->{input_file});
    $self->{input_file} = undef;
}

sub do
{

    my ($self, $func_name_or_ref,$package) = @_;
    
    ($self->{calling_package}) = caller;
    my ($func_type, $func_ref) = resolve_func_type($func_name_or_ref,$package);
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

sub resolve_func_type
{
    my ($func_name_or_ref, $package) = @_; #print join ' ',@DynaLoader::dl_modules,"\n";

    #if this is a perl code ref we're done 
    if(ref($func_name_or_ref) eq 'CODE')
    {
       return ('perl_func', $func_name_or_ref);
    }
    
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
			my @dl_modules = grep {  $string = $_; grep(/^$string$/,@dl); } @in;		
			
			foreach my $dl_package (@dl_modules)
			{
        		$package_number = dynaloader_has_package($dl_package);        	
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

1;
__DATA__
__C__

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))

typedef void (*do_func)(maqmap1_t *mm);

void * read_header(void * fpin)
{
    maqmap_t  *mm = maqmap_read_header(fpin);
    mm->n_mapped_reads = 0;
    return (void *)mm;
}

void * init_file(char *infile)
{
    gzFile fpin = gzopen(infile, "r");
    //read_header((void *)fpin);
    return (void *)fpin;
}

void close_file(void * fpin)
{
    gzclose((gzFile)fpin);
}

char * get_read(maqmap1_t *mm)
{
    static char string[MAX_READLEN];
    int j = 0;
    for (j = 0; j != mm->size; ++j) {
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
    for (j = 0; j != mm->size; ++j)
        av_push(AV_qual, newSViv((mm->seq[j]&0x3f) + 33));
    
    return newRV_inc((SV *)AV_qual);
}

SV * build_perl_hash(maqmap1_t *mm)
{
    HV * rec = newHV();
    sv_2mortal((SV *)rec);
    hv_store(rec, "name",4,newSVpv(mm->name,0),0);//printf("%s\n",mm->name);
    hv_store(rec, "size",4,newSViv(mm->size),0);
    hv_store(rec, "seq",3,newSVpvn(get_read(mm),mm->size),0);
    hv_store(rec, "pos",3,newSViv(mm->pos),0);
    hv_store(rec, "seqid",5,newSViv(mm->seqid),0);
    hv_store(rec, "qual",4,get_qual(mm),0);
    hv_store(rec, "single_end_map_qual",sizeof("single_end_map_qual"),newSViv(mm->seq[MAX_READLEN]),0);
    hv_store(rec, "map_qual",8,newSViv(mm->map_qual),0);
    hv_store(rec, "alt_qual",8,newSViv(mm->alt_qual),0);
    hv_store(rec, "flag",4,newSViv(mm->flag),0);
    hv_store(rec, "dist",4,newSViv(mm->dist),0);
    hv_store(rec, "24bp_mismatches",sizeof("24bp_mismatches"),newSViv(mm->info1>>4),0);
    hv_store(rec, "mismatches",sizeof("mismatches"),newSViv(mm->info1|0x0f),0);
    hv_store(rec, "info2",5,newSViv(mm->info2),0);
    hv_store(rec, "c",1,newSViv((*(int *)(&mm->c[0]))|0x0FFF),0);
    //return sv_2mortal((SV *)newRV_inc((SV *)rec));
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
    maqmap_t  *mm = maqmap_read_header((gzFile)fpin);
    mm->n_mapped_reads = 0;
    do_func func = tempfunc;
    
    static maqmap1_t curr_mm;
    
    while(get_record((gzFile)fpin, &curr_mm))
    {
        (*func)(&curr_mm);
    }
}
