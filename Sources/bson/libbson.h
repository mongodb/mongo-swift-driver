#define BCON_H_
#include <bson.h>

uint32_t _bson_get_len(const bson_t *bson)
{
    BSON_ASSERT (bson);
    return bson->len;
}
