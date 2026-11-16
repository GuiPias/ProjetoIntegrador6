package br.com.projetointegrador.produtos;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class ProdutosApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProdutosApplication.class, args);
    }

    // Insere dados de exemplo quando a tabela estiver vazia (o banco é recriado a cada ambiente).
    @Bean
    CommandLineRunner dadosDeExemplo(ProdutoRepository repository) {
        return args -> {
            if (repository.count() == 0) {
                repository.save(new Produto("Teclado", 25));
                repository.save(new Produto("Mouse", 40));
                repository.save(new Produto("Monitor", 8));
            }
        };
    }
}
