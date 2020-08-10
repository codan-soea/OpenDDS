#ifndef OPENDDS_RTPS_TYPE_LOOKUP_H_
#define OPENDDS_RTPS_TYPE_LOOKUP_H_

/*
 * Distributed under the OpenDDS License.
 * See: http://www.opendds.org/license.html
 */

#include "RtpsRpcTypeSupportImpl.h"
#include <dds/DCPS/XTypes/TypeObject.h>

OPENDDS_BEGIN_VERSIONED_NAMESPACE_DECL

namespace OpenDDS {
namespace XTypes {

  // As per chapter 7.6.3.3.3 of XTypes spec
  // Used in TypeLookup_Call and TypeLookup_Return
  const CORBA::ULong TypeLookup_getTypes_HashId = 25318099U;
  const CORBA::ULong TypeLookup_getDependencies_HashId = 95091505U;

  struct TypeLookup_getTypes_In
  {
    TypeIdentifierSeq type_ids;

    TypeLookup_getTypes_In() {}
  };

  struct TypeLookup_getTypes_Out
  {
    TypeIdentifierTypeObjectPairSeq types;
    TypeIdentifierPairSeq complete_to_minimal;

    TypeLookup_getTypes_Out() {}
  };

  struct TypeLookup_getTypes_Result
  {
    TypeLookup_getTypes_Out result;

    TypeLookup_getTypes_Result() {}
  };

#if !defined (_OPENDDS_XTYPES_OCTET32SEQ_CH_)
#define _OPENDDS_XTYPES_OCTET32SEQ_CH_

  class Octet32Seq;

  typedef
    ::TAO_FixedSeq_Var_T<
    Octet32Seq
    >
    Octet32Seq_var;

  typedef
    ::TAO_Seq_Out_T<
    Octet32Seq
    >
    Octet32Seq_out;

  class  Octet32Seq
    : public
    ::TAO::bounded_value_sequence<
    ::CORBA::Octet,
    32
    >
  {
  public:
    Octet32Seq(void) {};
    Octet32Seq(
      ::CORBA::ULong length,
      ::CORBA::Octet* buffer,
      ::CORBA::Boolean release = false) : ::TAO::bounded_value_sequence<::CORBA::Octet, 32> (length, buffer, release) {};
#if defined (ACE_HAS_CPP11)
    Octet32Seq(const Octet32Seq&) = default;
    Octet32Seq(Octet32Seq&&) = default;
    Octet32Seq& operator= (const Octet32Seq&) = default;
    Octet32Seq& operator= (Octet32Seq&&) = default;
#endif /* ACE_HAS_CPP11 */
    virtual ~Octet32Seq(void) {};

    typedef Octet32Seq_var _var_type;
    typedef Octet32Seq_out _out_type;
  };

#endif /* end #if !defined */

  typedef Octet32Seq ContinuationPoint;

  struct TypeLookup_getTypeDependencies_In
  {
    TypeIdentifierSeq type_ids;
    ContinuationPoint continuation_point;

    TypeLookup_getTypeDependencies_In() {}
  };

  struct TypeLookup_getTypeDependencies_Out
  {
    TypeIdentifierWithSizeSeq dependent_typeids;
    ContinuationPoint continuation_point;

    TypeLookup_getTypeDependencies_Out() {}
  };

  struct TypeLookup_getTypeDependencies_Result
  {
    TypeLookup_getTypeDependencies_Out result;

    TypeLookup_getTypeDependencies_Result() {}
  };

  struct TypeLookup_Call
  {
    CORBA::ULong kind;
    TypeLookup_getTypes_In getTypes;
    TypeLookup_getTypeDependencies_In getTypeDependencies;

    TypeLookup_Call() {}
  };

  struct TypeLookup_Request
  {
    DDS::RPC::RequestHeader header;
    TypeLookup_Call data;

    TypeLookup_Request() {}
  };

  struct TypeLookup_Return
  {
    CORBA::ULong kind;
    TypeLookup_getTypes_Result getTypes;
    TypeLookup_getTypeDependencies_Result getTypeDependencies;

    TypeLookup_Return() {}
  };

  struct TypeLookup_Reply
  {
    DDS::RPC::ResponseHeader header;
    TypeLookup_Return data;

    TypeLookup_Reply() {}
  };
} // namespace XTypes

namespace DCPS {

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_getTypes_In& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_getTypes_In& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_getTypes_In& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_getTypes_Out& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_getTypes_Out& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_getTypes_Out& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_getTypes_Result& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_getTypes_Result& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_getTypes_Result& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::ContinuationPoint& arr);
  bool operator<<(DCPS::Serializer& ser, const XTypes::ContinuationPoint& _tao_sequence);
  bool operator>>(DCPS::Serializer& ser, XTypes::ContinuationPoint& _tao_sequence);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_getTypeDependencies_In& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_getTypeDependencies_In& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_getTypeDependencies_In& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_getTypeDependencies_Out& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_getTypeDependencies_Out& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_getTypeDependencies_Out& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_getTypeDependencies_Result& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_getTypeDependencies_Result& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_getTypeDependencies_Result& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_Call& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_Call& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_Call& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_Request& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_Request& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_Request& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_Return& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_Return& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_Return& stru);

  void serialized_size(const DCPS::Encoding& encoding, size_t& size,
    const XTypes::TypeLookup_Reply& stru);
  bool operator<<(DCPS::Serializer& strm, const XTypes::TypeLookup_Reply& stru);
  bool operator>>(DCPS::Serializer& strm, XTypes::TypeLookup_Reply& stru);
} // namespace DCPS
} // namespace OpenDDS

OPENDDS_END_VERSIONED_NAMESPACE_DECL

#endif /* ifndef OPENDDS_RTPS_TYPE_LOOKUP_H_ */
