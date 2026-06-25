package com.bookstore.service.books.mappers;

import com.bookstore.service.books.dto.BookDto;
import com.bookstore.service.books.entities.Book;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface BookMapper {

    BookDto toBookDto(Book book);
}
