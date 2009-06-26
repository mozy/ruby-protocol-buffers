#include "ruby.h"

static VALUE Protobuf, Varint;
static ID getbyte, putbyte;

static VALUE varint_encode(VALUE module, VALUE io, VALUE int_valV)
{
    /* unsigned for the bit shifting ops */
    unsigned long long int_val = (unsigned long long)NUM2LL(int_valV);
    unsigned char byte;
    while (1) {
        byte = int_val & 0x7f;
        int_val >>= 7;
        if (int_val == 0) {
            rb_funcall(io, putbyte, 1, INT2FIX(byte));
            return Qnil;
        } else {
            rb_funcall(io, putbyte, 1, INT2FIX(byte | 0x80));
        }
    }
}

static VALUE varint_decode(VALUE module, VALUE io)
{
    unsigned long long int_val = 0;
    unsigned shift = 0;
    unsigned char byte;

    while (1) {
        if (shift >= 64) {
            rb_raise(rb_eArgError, "too many bytes when decoding varint");
        }
        byte = (unsigned char)FIX2INT(rb_funcall(io, getbyte, 0));
        int_val |= ((unsigned long long)(byte & 0x7f)) << shift;
        shift += 7;
        if ((byte & 0x80) == 0) {
            /* return ULL2NUM(int_val); */
            return LL2NUM((long long)int_val);
        }
    }
}

void Init_ruby_protobufs()
{
    Protobuf = rb_define_module("Protobuf");
    Varint = rb_define_module_under(Protobuf, "Varint");

    VALUE zero = INT2FIX(0);
    VALUE test_io = rb_class_new_instance(1, &zero,
            rb_const_get(rb_cObject, rb_intern("IO")));

    /* hackish way to support both 1.8.6 and 1.8.7+ */
    getbyte = rb_intern("getbyte");
    if (!rb_respond_to(test_io, getbyte)) {
        getbyte = rb_intern("getc");
    }

    /* TODO: check the api docs -- what happens to test_io here?
     * does it just leak? */

    putbyte = rb_intern("putc");

    rb_define_module_function(Varint, "encode", varint_encode, 2);
    rb_define_module_function(Varint, "decode", varint_decode, 1);
}
