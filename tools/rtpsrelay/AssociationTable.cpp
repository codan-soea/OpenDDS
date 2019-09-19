#include "AssociationTable.h"

#include "dds/DCPS/DCPS_Utils.h"

void AssociationTable::insert(const RtpsRelay::WriterEntry& writer)
{
  if (writer.relay_addresses() == relay_addresses_) {
    // A writer connected to this relay.
    local_writers_[writer.guid()] = writer;
    for (const auto p : local_readers_) {
      attempt_match(writer, true, p.second, true);
    }
    for (const auto p : remote_readers_) {
      attempt_match(writer, true, p.second, false);
    }
  } else {
    // A writer connected to another relay.
    remote_writers_[writer.guid()] = writer;
    for (const auto p : local_readers_) {
      attempt_match(writer, false, p.second, true);
    }
  }
}

void AssociationTable::remove(const RtpsRelay::WriterEntry& writer)
{
  if (writer.relay_addresses() == relay_addresses_) {
    // A writer connected to this relay.
    remove_local(writer.guid());
    local_writers_.erase(writer.guid());
  } else {
    remove_remote(writer.guid());
    remote_writers_.erase(writer.guid());
  }
}

void AssociationTable::insert(const RtpsRelay::ReaderEntry& reader)
{
  if (reader.relay_addresses() == relay_addresses_) {
    // A reader connected to this relay.
    local_readers_[reader.guid()] = reader;
    for (const auto p : local_writers_) {
      attempt_match(p.second, true, reader, true);
    }
    for (const auto p : remote_writers_) {
      attempt_match(p.second, false, reader, true);
    }
  } else {
    // A reader connected to another relay.
    remote_readers_[reader.guid()] = reader;
    for (const auto p : local_writers_) {
      attempt_match(p.second, true, reader, false);
    }
  }
}

void AssociationTable::remove(const RtpsRelay::ReaderEntry& reader)
{
  if (reader.relay_addresses() == relay_addresses_) {
    // A writer connected to this relay.
    remove_local(reader.guid());
    local_readers_.erase(reader.guid());
  } else {
    remove_remote(reader.guid());
    remote_readers_.erase(reader.guid());
  }
}

void AssociationTable::attempt_match(const RtpsRelay::WriterEntry& writer,
                                     bool writer_local,
                                     const RtpsRelay::ReaderEntry& reader,
                                     bool reader_local)
{
  // Not used.  Null cannot be passed to compatibleQOS.
  OpenDDS::DCPS::IncompatibleQosStatus writer_status;
  OpenDDS::DCPS::IncompatibleQosStatus reader_status;

  if (writer.topic_name() == reader.topic_name() &&
      writer.type_name() == reader.type_name() &&
      OpenDDS::DCPS::compatibleQOS(&writer._data_writer_qos, &reader._data_reader_qos, &writer_status, &reader_status) &&
      OpenDDS::DCPS::compatibleQOS(&writer._publisher_qos, &reader._subscriber_qos, &writer_status, &reader_status) &&
      OpenDDS::DCPS::matching_partitions(writer._publisher_qos.partition, reader._subscriber_qos.partition)) {
    if (writer_local) {
      record_next_hop(writer.guid(), reader.guid());
    }
    if (reader_local) {
      record_next_hop(reader.guid(), writer.guid());
    }
  } else {
    if (writer_local) {
      erase_next_hop(writer.guid(), reader.guid());
    }
    if (reader_local) {
      erase_next_hop(reader.guid(), writer.guid());
    }
  }
}

void AssociationTable::record_next_hop(const RtpsRelay::GUID_t& local_guid,
                                       const RtpsRelay::GUID_t& other_guid)
{
  auto p = forward_map_.insert(std::make_pair(local_guid, GuidSet()));
  p.first->second.insert(other_guid);

  auto q = reverse_map_.insert(std::make_pair(other_guid, GuidSet()));
  q.first->second.insert(local_guid);
}

void AssociationTable::erase_next_hop(const RtpsRelay::GUID_t& local_guid,
                                      const RtpsRelay::GUID_t& other_guid)
{
  auto pos = forward_map_.find(local_guid);
  if (pos != forward_map_.end()) {
    if (pos->second.count(other_guid) != 0) {
      pos->second.erase(other_guid);
      auto pos2 = reverse_map_.find(other_guid);
      pos2->second.erase(local_guid);
      if (pos2->second.empty()) {
        reverse_map_.erase(pos2);
      }
    }
  }
}

void AssociationTable::remove_local(const RtpsRelay::GUID_t& guid)
{
  auto pos = forward_map_.find(guid);
  if (pos != forward_map_.end()) {
    for (const auto remote : pos->second) {
      auto pos2 = reverse_map_.find(remote);
      pos2->second.erase(guid);
      if (pos2->second.empty()) {
        reverse_map_.erase(pos2);
      }
    }
    forward_map_.erase(pos);
  }
}

void AssociationTable::remove_remote(const RtpsRelay::GUID_t& guid)
{
  auto pos = reverse_map_.find(guid);
  if (pos != reverse_map_.end()) {
    for (const auto local_guid : pos->second) {
      auto pos2 = forward_map_.find(local_guid);
      pos2->second.erase(guid);
      if (pos2->second.empty()) {
        forward_map_.erase(pos2);
      }
    }
    reverse_map_.erase(pos);
  }
}

RtpsRelay::RelayAddresses AssociationTable::get_relay_addresses(const RtpsRelay::GUID_t& guid) const
{
  RtpsRelay::GUID_t prefix;
  prefix.guidPrefix(guid.guidPrefix());
  prefix.entityId(ENTITYID_UNKNOWN);

  {
    auto pos = remote_writers_.lower_bound(prefix);
    if (pos != remote_writers_.end()) {
      return pos->second.relay_addresses();
    }
  }
  {
    auto pos = remote_readers_.lower_bound(prefix);
    if (pos != remote_readers_.end()) {
      return pos->second.relay_addresses();
    }
  }
  return RtpsRelay::RelayAddresses();
}

void AssociationTable::get_guids_from_local(const RtpsRelay::GUID_t& guid, GuidSet& guids) const
{
  // Match on the prefix.
  RtpsRelay::GUID_t prefix;
  prefix.guidPrefix(guid.guidPrefix());
  prefix.entityId(ENTITYID_UNKNOWN);

  for (auto pos = forward_map_.lower_bound(prefix), limit = forward_map_.end();
       pos != limit && pos->first.guidPrefix() == prefix.guidPrefix(); ++pos) {
    for (auto x : pos->second) {
      x.entityId(ENTITYID_UNKNOWN);
      guids.insert(x);
    }
  }
}

void AssociationTable::get_guids_to_local(const RtpsRelay::GUID_t& guid, GuidSet& guids) const
{
  // Match on the prefix.
  RtpsRelay::GUID_t prefix;
  prefix.guidPrefix(guid.guidPrefix());
  prefix.entityId(ENTITYID_UNKNOWN);

  for (auto pos = reverse_map_.lower_bound(prefix), limit = reverse_map_.end();
       pos != limit && pos->first.guidPrefix() == prefix.guidPrefix(); ++pos) {
    for (auto x : pos->second) {
      x.entityId(ENTITYID_UNKNOWN);
      guids.insert(x);
    }
  }
}
