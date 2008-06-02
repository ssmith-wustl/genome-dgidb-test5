typedef void (*ov_callback_t)(void *variation, gqueue * reads);

class ov_item
{
public:
    ov_item();
    ~ov_item();
    long long begin()=0;
    long long end()=0;
}

          
class ov_iterator
{
public:
    ov_item * next()=0;
}

//commonly used implementations

class ov_map_item : public ov_item
{
public:
    ov_map_item(maqmap1_t *m1) { this->m1 = m1; }
    
    long long begin() { return (m1->pos)>>1; }
    long long end() { return ((m1->pos)>>1)+(m1->size)-1; }
    
    //data pointer
    maqmap1_t *m1;    
}

class ov_map_iterator : public ov_iterator
{
public:
    ov_map_iterator(char *map_file_name)
    {
        map_file = gzopen(map_file_name, "r");   
        mm = maqmap_read_header(map_file);
                
    }
    ~ov_map_iterator()
    {
        maq_delete_maqmap(mm);
        gzclose(map_file);    
    }
    ov_map_item * next()
    {
        if(gzread(map_file, &m1, sizeof(maqmap1_t))
            return new ov_map_item(m1);
        else
            return NULL;           
    }
private:
    gzFile map_file;
    maqmap_t *mm; 
    maqmap1_t m1;
}

//snp iterator implementation
class ov_snp_item : public ov_item
{
public:
    ov_snp_item(snp_item *item)
    {
                    
    }

    long long begin()
    {
        return 
    }
    long long end()
    {
        return ((m1->pos)>>1)+(m1->size)-1;
    }
    private:
    

}

class ov_snp_iterator : public ov_iterator
{
public:
    ov_snp_iterator(snp_array *snps)
    {
        map_file = gzopen(map_file_name, "r");   
        mm = maqmap_read_header(map_file);
                
    }
    ~ov_snp_iterator()
    {
        maq_delete_maqmap(mm);
        gzclose(map_file);    
    }
    ov_snp_item * next()
    {
        if(gzread(map_file, &m1, sizeof(maqmap1_t))
            return new ov_map_item(m1);
        else
            return NULL;           
    }
private:
    gzFile map_file;
    maqmap_t *mm; 
    maqmap1_t m1;
}
