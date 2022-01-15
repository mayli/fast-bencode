# cython: language_level=3
from typing import Tuple, List
from io import BytesIO

class BTFailure(Exception):
    pass


def decode_int(x: bytes, f: int) -> Tuple[int, int]:
    """
    i开头 e结束 i123e
    :param x:
    :param f:
    :return:
    """
    # assert x[f] == "i"
    f += 1
    end = x.index(b'e', f)
    number = int(x[f:end])
    if x[f] == 45:  # '-'
        if x[f + 1] == 48:  # ord('0')
            raise ValueError
    elif x[f] == 48 and end != f + 1:  # 不能加多余的0
        raise ValueError
    return (number, end + 1)


def decode_string(x: bytes, f: int) -> Tuple[str, int]:
    """
    :param x: 3:abc
    :param f: 偏移
    :return: 解析出来的字符串和下一个偏移
    """
    colon = x.index(b':', f)  # ：的索引
    length = int(x[f:colon])  # 长度
    if x[f] == 48 and colon != f + 1:
        raise ValueError
    colon += 1
    try:
        return (x[colon:colon + length].decode(), colon + length)
    except UnicodeDecodeError:
        return (x[colon:colon + length], colon + length)

def decode_list(x: bytes, f: int) -> Tuple[list, int]:
    """
    l3:abci123ee
    :param x:
    :param f:
    :return:
    """
    # assert x[f] == "l"
    ret, f = [], f + 1
    while x[f] != 101:
        v, f = decode_func[x[f]](x, f)
        ret.append(v)
    return (ret, f + 1)


def decode_dict(x: bytes, f: int) -> Tuple[dict, int]:
    """

    :param x:
    :param f: 偏移量
    :return:
    """
    r, f = {}, f + 1
    while x[f] != 101:  # dict 以e结束  ord(e)
        k, f = decode_string(x, f)
        r[k], f = decode_func[x[f]](x, f)
    return (r, f + 1)


decode_func = {}
decode_func[ord('l')] = decode_list
decode_func[ord('d')] = decode_dict  # type: ignore
decode_func[ord('i')] = decode_int  # type: ignore
decode_func[ord('0')] = decode_string  # type: ignore
decode_func[ord('1')] = decode_string  # type: ignore
decode_func[ord('2')] = decode_string  # type: ignore
decode_func[ord('3')] = decode_string  # type: ignore
decode_func[ord('4')] = decode_string  # type: ignore
decode_func[ord('5')] = decode_string  # type: ignore
decode_func[ord('6')] = decode_string  # type: ignore
decode_func[ord('7')] = decode_string  # type: ignore
decode_func[ord('8')] = decode_string  # type: ignore
decode_func[ord('9')] = decode_string  # type: ignore


def bdecode(x: bytes):
    """
    bdecode(x: bytes) -> Any

    """
    try:
        r, l = decode_func[x[0]](x, 0)
    except (IndexError, KeyError, ValueError):
        raise BTFailure("not a valid bencoded string")
    if l != len(x):
        raise BTFailure("invalid bencoded value (data after valid prefix)")
    return r


cdef class Bencached(object):
    cdef public bytes bencoded

    def __cinit__(self, bytes s):
        self.bencoded = s  # type: bytes


def encode_bencached(Bencached x, r: BytesIO):
    r.write(x.bencoded)


def encode_int(x: int, r: BytesIO):
    r.write(b''.join((b'i', str(x).encode(), b'e')))


def encode_bool(x, r):
    if x:
        encode_int(1, r)
    else:
        encode_int(0, r)


def encode_string(x: str, r: BytesIO):
    r.write(b''.join((str(len(x.encode())).encode(), b':', x.encode())))


def encode_bytes(x: bytes, r: BytesIO):
    r.write(b''.join((str(len(x)).encode(), b':', x)))


def encode_list(x: list, r: BytesIO):
    r.write(b'l')
    for i in x:
        encode_func[type(i)](i, r)
    r.write(b'e')


def encode_dict(x: dict, ret: BytesIO):
    ret.write(b'd')
    ilist = list(x.items())
    ilist.sort()
    for k, v in ilist:
        ret.write(b''.join((str(len(k)).encode(), b':', k.encode() if isinstance(k, str) else k)))
        encode_func[type(v)](v, ret)
    ret.write(b'e')


encode_func = {}
encode_func[Bencached] = encode_bencached
encode_func[int] = encode_int  # type: ignore
encode_func[str] = encode_string  # type: ignore
encode_func[bytes] = encode_bytes  # type: ignore
encode_func[list] = encode_list  # type: ignore
encode_func[tuple] = encode_list  # type: ignore
encode_func[dict] = encode_dict  # type: ignore
encode_func[bool] = encode_bool  # type: ignore


def bencode(x) -> bytes:
    """
    bencode(x) -> bytes

    """
    r = BytesIO()  # todo bytearray
    encode_func[type(x)](x, r)
    return r.getvalue()
