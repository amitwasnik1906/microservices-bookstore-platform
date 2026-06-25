package com.bookstore.service.prices.mappers;

import com.bookstore.service.prices.dto.PriceDto;
import com.bookstore.service.prices.entities.Price;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface PriceMapper {

    PriceDto toPriceDto(Price price);
}
