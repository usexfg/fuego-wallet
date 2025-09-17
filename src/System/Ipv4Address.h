#ifndef SYSTEM_IPV4ADDRESS_H
#define SYSTEM_IPV4ADDRESS_H

#include <string>
#include <stdexcept>
#include <arpa/inet.h>

namespace System {

class Ipv4Address {
public:
    Ipv4Address() = default;
    explicit Ipv4Address(const std::string& address) : m_address(address) {}

    ~Ipv4Address() = default;

    std::string toString() const { return m_address; }

    std::string toDottedDecimal() const { return toString(); }

    /**
     * Parse the IPv4 address string and return a host-order uint32_t.
     */
    uint32_t getValue() const {
        struct in_addr in_addr_struct;
        if (inet_pton(AF_INET, m_address.c_str(), &in_addr_struct) != 1) {
            throw std::runtime_error("Invalid IPv4 address: " + m_address);
        }
        return ntohl(in_addr_struct.s_addr);
    }

private:
    std::string m_address;
};

} // namespace System

#endif // SYSTEM_IPV4ADDRESS_H
